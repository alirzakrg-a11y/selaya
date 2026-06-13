import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';

import '../../../core/router/routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../prayer_times/domain/prayer.dart';
import '../data/prayer_notification_controller.dart';
import '../data/prayer_scheduler.dart';
import '../domain/prayer_notification_settings.dart';

/// Full-screen adhan alarm shown when a prayer comes in: it fills the screen and
/// wakes the device (alarm-clock UX) until the user taps "Durdur". GÖRSEL
/// katmandır: ezanın SESİ native AdhanPlayerService'te çalar (alarm-tetikli
/// MediaPlayer — uygulama ölü olsa bile). Bu ekran açılırken sesi KESMEZ
/// (eskiden cancelActivePrayerSounds çağırıp kendi just_audio'suyla çalıyordu →
/// "ekran açılınca sustu" / çift-ezan sorunları). "Durdur" native sesi durdurur.
/// Reached via the full-screen intent / tap and the in-app watcher (app.dart).
class AdhanAlarmScreen extends ConsumerStatefulWidget {
  const AdhanAlarmScreen({super.key, required this.slotIndex});
  final int slotIndex;

  @override
  ConsumerState<AdhanAlarmScreen> createState() => _AdhanAlarmScreenState();
}

class _AdhanAlarmScreenState extends ConsumerState<AdhanAlarmScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  double _volume = 1.0;
  static const _adhanChannel = MethodChannel('selaya/widget');

  PrayerSlot get _slot =>
      PrayerSlot.values[widget.slotIndex.clamp(0, PrayerSlot.values.length - 1)];

  @override
  void initState() {
    super.initState();
    adhanAlarmIsOpen = true;
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    // Titreşim ayarı açıksa ezan boyunca ~3 sn süren güçlü titreşim (0.8 sn ara
    // ile tekrarlar). Sessiz görsel bildirimde kanal titreşimi yok → ekran
    // kendi titretir.
    if (prayerVibration) {
      Vibration.vibrate(pattern: const [0, 3000, 800], repeat: 0);
    }
  }

  Future<void> _stopAndClose() async {
    Vibration.cancel();
    // Native ezanı durdur + görünür bildirimleri iptal et. Bazı cihazlarda (One
    // UI) bildirim ilk çağrıda yakalanmadığı için kısa gecikmeyle bir kez daha.
    final notif = ref.read(notificationServiceProvider);
    await notif.cancelActivePrayerSounds();
    Future.delayed(const Duration(milliseconds: 350),
        notif.cancelActivePrayerSounds);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      // Opened via `go` (lock screen) → it is the ONLY route. SystemNavigator
      // alone backgrounds the app but LEAVES the alarm as the current route, so
      // re-opening the app got STUCK on it. Reset the route to home FIRST (so
      // re-entry never lands back on the alarm), THEN background the app (return
      // to the lock screen) like dismissing a phone alarm.
      context.go(Routes.home);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await SystemNavigator.pop();
    }
  }

  /// Ezan duası (#C-6): the supplication recited after the adhan — Arabic +
  /// Turkish reading + meaning, in a bottom sheet over the alarm.
  void _showEzanDua() {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('notif.ezanDua'.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: c.gold, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Text(
                'اللَّهُمَّ رَبَّ هَٰذِهِ الدَّعْوَةِ التَّامَّةِ وَالصَّلَاةِ الْقَائِمَةِ آتِ مُحَمَّدًا الْوَسِيلَةَ وَالْفَضِيلَةَ وَابْعَثْهُ مَقَامًا مَّحْمُودًا الَّذِي وَعَدْتَهُ',
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: AppTypography.arabic(
                    color: c.textPrimary, fontSize: 25, height: 2.0),
              ),
              const SizedBox(height: 18),
              Text('notif.ezanDuaReading'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: c.gold, height: 1.5, fontStyle: FontStyle.italic)),
              const SizedBox(height: 14),
              Text('notif.ezanDuaMeaning'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary, height: 1.55)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    adhanAlarmIsOpen = false;
    Vibration.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final name = _slot.labelKey.tr();

    return PopScope(
      canPop: false, // must be dismissed via the buttons
      child: Scaffold(
        backgroundColor: c.bg,
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 1.1,
              colors: [
                c.goldDeep.withValues(alpha: 0.45),
                c.bg,
                c.bg,
              ],
              stops: const [0, 0.6, 1],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // ── Top: label + live clock ───────────────────────────────
                  Text('notif.adhanLabel'.tr(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: c.gold,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(formatClockSeconds(now),
                      style: AppTypography.countdown(c.textSecondary,
                          fontSize: 18)),

                  const Spacer(),

                  // ── Center: pulsing prayer emblem ─────────────────────────
                  // PERF: yalnız saydam halkalar pulse'lanır (ucuz). Gradyan +
                  // BLUR gölgeli merkez amblem AnimatedBuilder'ın DIŞINDA →
                  // pahalı blur (blurRadius 30) her karede DEĞİL bir kez çizilir;
                  // RepaintBoundary pulse'ı ekranın geri kalanından yalıtır.
                  // (Ezan boyunca 60fps blur-repaint = "ezan okunurken donma".)
                  RepaintBoundary(
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (context, _) {
                              final t = _pulse.value;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  for (final scale in [1.0, 0.78])
                                    Container(
                                      width: 220 * (scale + t * 0.12),
                                      height: 220 * (scale + t * 0.12),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: c.gold.withValues(
                                            alpha: 0.06 + (1 - scale) * 0.05),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          Container(
                            width: 132,
                            height: 132,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [c.goldBright, c.goldDeep],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: c.gold.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(_slot.icon, size: 60, color: c.bg),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  Text(name,
                      style:
                          Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w800,
                              )),
                  const SizedBox(height: 8),
                  Text('notif.atTimeNamed'.tr(args: [name]),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: c.gold)),

                  const SizedBox(height: 18),
                  // Ezan duası — read after the adhan.
                  OutlinedButton.icon(
                    onPressed: _showEzanDua,
                    icon: const Icon(Icons.volunteer_activism_rounded, size: 18),
                    label: Text('notif.ezanDua'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.gold,
                      side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99)),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Ses seviyesi — ezanı buradan kısabilirsin (sistem alarm
                  // sesinden bağımsız, anında etki eder).
                  Row(
                    children: [
                      Icon(Icons.volume_up_rounded,
                          size: 20, color: c.textSecondary),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          activeColor: c.gold,
                          onChanged: (v) {
                            setState(() => _volume = v);
                            // Native çalan ezanın sesini anında ayarla.
                            _adhanChannel.invokeMethod(
                                'setAdhanVolume', v).ignore();
                          },
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── Bottom: disable full-screen (red) + stop ─────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref
                            .read(fullScreenAdhanProvider.notifier)
                            .set(false);
                        // Reschedule now so it takes effect immediately — the
                        // already-scheduled prayers drop their full-screen intent
                        // (they'll ring as a plain heads-up with "Durdur").
                        await ref.read(prayerSchedulerProvider).rescheduleAll();
                        await _stopAndClose();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.danger,
                        side: BorderSide(
                            color: c.danger.withValues(alpha: 0.7), width: 1.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('notif.adhanDisableFullScreen'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('notif.adhanDisableFullScreenDesc'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textTertiary)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: FilledButton(
                      onPressed: _stopAndClose,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.gold,
                        foregroundColor: c.bg,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stop_circle_outlined, size: 26),
                          const SizedBox(width: 10),
                          Text('notif.adhanStop'.tr(),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
