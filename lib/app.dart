import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import 'core/data/manifest_service.dart';
import 'core/data/notifications_sync.dart';
import 'core/di/providers.dart';
import 'core/router/app_router.dart';
import 'core/router/routes.dart';
import 'core/services/mosque_silent_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/permissions_controller.dart';
import 'core/services/widget_service.dart';
import 'core/services/widget_updater.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/global_mini_player_host.dart';
import 'features/auth/data/sync_service.dart';
import 'features/notifications/data/prayer_notification_controller.dart';
import 'features/notifications/data/prayer_scheduler.dart';
import 'features/notifications/data/special_notifications.dart';
import 'features/prayer_times/data/online_times.dart';
import 'features/prayer_times/data/prayer_repository.dart';
import 'features/prayer_times/domain/prayer.dart';
import 'features/settings/presentation/settings_controller.dart';

class SelayaApp extends ConsumerStatefulWidget {
  const SelayaApp({super.key});

  @override
  ConsumerState<SelayaApp> createState() => _SelayaAppState();
}

class _SelayaAppState extends ConsumerState<SelayaApp>
    with WidgetsBindingObserver {
  // Oturum "başka cihazda açıldı" bilgisini global snackbar ile göstermek için.
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reschedule prayer notifications + refresh home-screen widgets once the
    // first frame (and localisation) is ready; safe no-op without permission.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBackground());
    // Surface the full-screen adhan alarm when requested (notification tap /
    // full-screen intent / launch, and the in-app watcher below).
    adhanAlarmSlot.addListener(_onAlarmRequested);
  }

  @override
  void dispose() {
    adhanAlarmSlot.removeListener(_onAlarmRequested);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncBackground();
    // Arka plana alınınca yerel değişiklikleri buluta gönder (girişliyse).
    if (state == AppLifecycleState.paused) {
      ref.read(syncControllerProvider.notifier).push();
    }
  }

  void _syncBackground() {
    _reschedule();
    // Girişliyse: bulut başka cihazda güncellendiyse sessizce çek (çok-cihaz);
    // hesap başka yerde açıldığı için bu cihaz düşürüldüyse (en fazla 2 cihaz)
    // "çıkış yapıldı" bilgisini göster.
    ref.read(syncControllerProvider.notifier).syncOnResume().then((_) {
      if (mounted) _checkSessionRevoked();
    });
    // Resmî çevrimiçi vakitler her dönüşte tazelik bekçisinden geçer: 12 saatte
    // bir / kapsama 14 günün altına düşünce yeni ay çekilir → vakitler süresiz
    // güncel kalır (build zaten izliyor; invalidate yeniden hesaplatır).
    ref.invalidate(onlineTimesSyncProvider);
    // Panelden eklenen içerik, uygulamaya her dönüşte hemen görünsün diye
    // manifesti tazele (wallpapers/stories/feed/… bu manifesti izliyor).
    ref.invalidate(manifestProvider);
    // Keep the shared permission/service status fresh — a grant made in system
    // settings (exact alarm, battery, full-screen) is reflected on resume.
    ref.read(permissionsControllerProvider.notifier).refresh();
    // "Camide otomatik sessize al" açıksa: yakındaki camileri tazele + geofence'i
    // yeniden kur + anlık mesafe kontrolü uygula (seyahatte takip etsin; arka
    // plan izni yoksa en azından açılışta cami yanındaysa sustursun). Kapalıysa
    // no-op.
    ref.read(mosqueSilentControllerProvider.notifier).refresh();
    if (mounted) {
      pushHomeWidgets(ref, context.locale.languageCode);
      _checkPendingAdhan();
    }
  }

  /// Hesap başka cihazda açıldığı için bu cihaz düşürüldüyse (en fazla 2 cihaz)
  /// bir kez "çıkış yapıldı" bilgisi göster — senkron servisi oturumu çoktan
  /// kapattı (sessionRevoked).
  void _checkSessionRevoked() {
    final prefs = ref.read(sharedPreferencesProvider);
    final tr = context.locale.languageCode == 'tr';
    // ÖNCE ban: hesap engellendiyse kalıcı, net bir uyarı göster.
    if (prefs.getBool(PrefKeys.bannedFlag) ?? false) {
      prefs.remove(PrefKeys.bannedFlag);
      _messengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            backgroundColor: const Color(0xFFC0392B),
            content: Text(
              tr
                  ? '⛔ Hesabınız engellendi. Uygulamayı kullanmaya devam edemezsiniz.'
                  : '⛔ Your account has been blocked. You can no longer use the app.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      return;
    }
    if (!(prefs.getBool(PrefKeys.sessionRevoked) ?? false)) return;
    prefs.remove(PrefKeys.sessionRevoked);
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          tr
              ? 'Hesabın başka bir cihazda açıldığı için bu cihazdan çıkış yapıldı (en fazla 2 cihaz).'
              : 'Signed out: your account was opened on another device (max 2 devices).',
        ),
      ),
    );
  }

  /// Pops the full-screen adhan alarm if the native side stashed a slot when an
  /// at-time notification's full-screen intent launched/resumed the app.
  Future<void> _checkPendingAdhan() async {
    final p = await ref.read(widgetServiceProvider).getPendingAdhan();
    if (p != null && p.startsWith('adhan:')) {
      final idx = int.tryParse(p.substring('adhan:'.length));
      if (idx != null && idx >= 0) adhanAlarmSlot.value = idx;
    }
  }

  void _reschedule() {
    ref.read(prayerSchedulerProvider).rescheduleAll();
    ref.read(specialSchedulerProvider).rescheduleSpecial();
  }

  int? _lastAdhanSlot;
  DateTime? _lastAdhanAt;
  void _onAlarmRequested() {
    if (adhanAlarmSlot.value == null || adhanAlarmIsOpen) return;
    // Aynı vakit için kısa sürede TEK kez aç: bildirim full-screen intent +
    // in-app watcher + resume (getPendingAdhan) aynı anda/peş peşe tetikleyebilir
    // → ezan 2 kez çalmasın. (Vakitler saatlerce uzak olduğundan 5 dk güvenli.)
    final reqIdx = adhanAlarmSlot.value;
    if (reqIdx != null &&
        _lastAdhanSlot == reqIdx &&
        _lastAdhanAt != null &&
        DateTime.now().difference(_lastAdhanAt!).inMinutes < 5) {
      adhanAlarmSlot.value = null; // tüket + atla
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idx = adhanAlarmSlot.value;
      if (idx == null || adhanAlarmIsOpen) return;
      adhanAlarmSlot.value = null; // consume
      _lastAdhanSlot = idx;
      _lastAdhanAt = DateTime.now();
      // `go` (not push): make the full-screen alarm the ONLY visible route, so the
      // app's normal UI never shows behind it — it's a self-contained alarm. The
      // screen's "Durdur" then closes it (backgrounds the app to the lock screen).
      ref.read(routerProvider).go('${Routes.adhanAlarm}/$idx');
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    // Keep the official online prayer-times sync alive — fetches on start and on
    // city/method change so İmsak and all vakit stay authoritative + current.
    ref.watch(onlineTimesSyncProvider);
    // Panelden gönderilen özel bildirimleri açılışta çek + görülmeyenleri göster.
    ref.watch(customNotificationsSyncProvider);
    // Keep intl's date/number formatting in sync with the app locale so the
    // scheduler's "31 Mayıs Cumartesi" reminders read correctly.
    intl.Intl.defaultLocale = context.locale.languageCode;

    return MaterialApp.router(
      title: 'SELAYA',
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(palette: settings.palette),
      darkTheme: AppTheme.darkMode(
        amoled: settings.amoled,
        palette: settings.palette,
      ),
      themeMode: settings.themeMode,
      routerConfig: router,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      // Apply the user's in-app font size (#22 large-text mode), then clamp so
      // very large/small sizes never break our dense layouts.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(settings.textScale)),
        child: MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.35,
          child: _AdhanWatcher(
            // 🎛️ Global mini çalarlar root Navigator'ın da ÜSTÜNDE — kabuk +
            // push'lanan tüm detay rotalarında TEK instance görünür (sekme
            // başına kopya yok, state hep korunur). Konum/gizleme kuralları:
            // GlobalMiniPlayerOverlay (mini_player_chrome.dart'taki rota seti).
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const Positioned.fill(child: GlobalMiniPlayerOverlay()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fires the full-screen adhan alarm the instant a prayer with an at-time alarm
/// comes in *while the app is open*. (Background/locked is covered by the
/// notification's full-screen intent.) Rebuilds each clock tick but returns its
/// child unchanged, so the app subtree below is never rebuilt.
class _AdhanWatcher extends ConsumerStatefulWidget {
  const _AdhanWatcher({required this.child});
  final Widget child;

  @override
  ConsumerState<_AdhanWatcher> createState() => _AdhanWatcherState();
}

class _AdhanWatcherState extends ConsumerState<_AdhanWatcher> {
  DateTime? _prev;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).value;
    final view = ref.watch(prayerViewProvider).value;
    final config = ref.watch(prayerNotificationProvider);
    final fullScreen = ref.watch(fullScreenAdhanProvider);
    if (now != null && view != null && fullScreen) {
      final prev = _prev;
      _prev = now;
      if (prev != null && now.isAfter(prev)) {
        for (final slot in PrayerSlot.values) {
          if (!config.alarmFor(slot).atTime) continue;
          final t = view.today.timeOf(slot);
          final crossed = t.isAfter(prev) && !t.isAfter(now);
          // Ignore stale crossings after a long background gap (resume).
          if (crossed && now.difference(t).inSeconds.abs() < 90) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => adhanAlarmSlot.value = slot.index,
            );
          }
        }
      }
    }
    return widget.child;
  }
}
