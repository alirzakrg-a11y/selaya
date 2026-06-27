import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/permissions_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/permission_dialog.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../prayer_times/domain/prayer.dart';
import '../data/prayer_notification_controller.dart';
import '../data/prayer_scheduler.dart';
import '../data/special_notifications.dart';
import '../domain/prayer_notification_settings.dart';
import '../domain/ramadan_mode.dart';

const _offsetChoices = [10, 15, 20, 25, 30, 45];

String _soundName(AdhanSound s) =>
    s.properName ?? (s.labelKey != null ? s.labelKey!.tr() : s.id);

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Refresh the shared permission status when this screen opens — exact-alarm
    // / battery may have changed in system settings since it was last read.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(permissionsControllerProvider.notifier).refresh());
  }

  Future<void> _reschedule() =>
      ref.read(prayerSchedulerProvider).rescheduleAll();

  /// Titreşim/LED tercihini uygula: global + prefs + kanalları YENİDEN oluştur
  /// (yeni kanal id'leri → Android yeni ayarı alır) + bildirimleri yeniden zamanla.
  Future<void> _applyChannelPref({bool? vibration}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (vibration != null) {
      prayerVibration = vibration;
      await prefs.setBool(PrefKeys.notifVibration, vibration);
    }
    if (mounted) setState(() {});
    await ref.read(notificationServiceProvider).init();
    await _reschedule();
  }

  /// "Vakitleri Güncelle" — re-resolve the city (GPS/saved) so the prayer times
  /// recompute, then reschedule. Spins the icon while busy and AWAITS the city
  /// re-resolution before rescheduling (the old version rescheduled against the
  /// stale city before the invalidation landed → the "bug").
  Future<void> _refreshTimes() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      ref.invalidate(selectedCityProvider);
      await ref.read(selectedCityProvider.future);
      await _reschedule();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _refreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('notif.refreshTimesDone'.tr())));
  }

  Future<void> _openSettings(String title, String message) =>
      showOpenSettingsDialog(context, ref.read(permissionServiceProvider),
          title: title, message: message);

  Future<void> _requestPermission() async {
    final outcome = await ref
        .read(permissionsControllerProvider.notifier)
        .requestNotifications();
    if (outcome.isGranted) {
      await _reschedule();
    } else if (outcome.needsSettings && mounted) {
      await _openSettings('notif.permissionDeniedTitle'.tr(),
          'notif.permissionDeniedBody'.tr());
    }
  }

  Future<void> _requestExact() async {
    final outcome = await ref
        .read(permissionsControllerProvider.notifier)
        .requestExactAlarm();
    if (outcome.needsSettings && mounted) {
      await _openSettings(
          'notif.exactAlarm'.tr(), 'notif.exactDeniedBody'.tr());
    }
    await _reschedule();
  }

  Future<void> _requestBattery() async {
    final outcome = await ref
        .read(permissionsControllerProvider.notifier)
        .requestBatteryExemption();
    if (outcome.needsSettings && mounted) {
      await _openSettings('notif.battery'.tr(), 'notif.batteryDeniedBody'.tr());
    }
  }

  Future<void> _requestOverlay() async {
    final outcome = await ref
        .read(permissionsControllerProvider.notifier)
        .requestOverlay();
    if (outcome.needsSettings && mounted) {
      await _openSettings('notif.overlay'.tr(), 'notif.overlayDeniedBody'.tr());
    }
  }

  /// Android 14+ "tam ekran bildirim" özel erişimi — ezan alarmının kilit
  /// ekranında tam ekran açılması için gerekir. Sistem sayfasını açar; sonuç
  /// app resume'da yenilenir.
  Future<void> _requestFullScreen() => ref
      .read(permissionsControllerProvider.notifier)
      .requestFullScreenIntent();

  // _warnFullScreenPermission KALDIRILDI — tam ekran ezan kaldırıldı.

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(prayerNotificationProvider);
    final ongoing = ref.watch(ongoingNotificationProvider);
    final perms = ref.watch(permissionsControllerProvider);

    return SelayaScaffold(
      title: 'notif.title'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          // İzinler — açılır menü; eksik kritik izin varsa (pil hariç) başlıkta ⚠.
          _PermissionsCard(
            hasWarning: !perms.notifications ||
                !perms.exactAlarm ||
                (Platform.isAndroid &&
                    (!perms.overlay || !perms.fullScreenIntent)),
            rows: [
              _StatusRow(
                icon: AppIcons.notification,
                label: 'notif.permission'.tr(),
                granted: perms.notifications,
                onGrant: _requestPermission,
              ),
              const _Divider(),
              _StatusRow(
                icon: AppIcons.kerahat,
                label: 'notif.exactAlarm'.tr(),
                subtitle: 'notif.exactAlarmDesc'.tr(),
                granted: perms.exactAlarm,
                onGrant: _requestExact,
              ),
              // Battery optimization (Doze) exemption — Android only. The OS
              // can otherwise defer/drop background prayer alarms.
              if (Platform.isAndroid) ...[
                const _Divider(),
                _StatusRow(
                  icon: AppIcons.battery,
                  label: 'notif.battery'.tr(),
                  subtitle: 'notif.batteryDesc'.tr(),
                  granted: perms.batteryExempt,
                  onGrant: _requestBattery,
                ),
                const _Divider(),
                // Draw-over-other-apps: lets the full-screen adhan launch over
                // other apps / from the background reliably (#overlay).
                _StatusRow(
                  icon: AppIcons.notification,
                  label: 'notif.overlay'.tr(),
                  subtitle: 'notif.overlayDesc'.tr(),
                  granted: perms.overlay,
                  onGrant: _requestOverlay,
                ),
                const _Divider(),
                // Android 14+: full-screen-intent special access — without it
                // the adhan alarm degrades to a heads-up and won't pop over the
                // lock screen (which is exactly the user's report).
                _StatusRow(
                  icon: Icons.fullscreen_rounded,
                  label: 'notif.fullScreenPerm'.tr(),
                  subtitle: 'notif.fullScreenPermDesc'.tr(),
                  granted: perms.fullScreenIntent,
                  onGrant: _requestFullScreen,
                ),
              ],
            ],
          ),
          // ── General: master switch · full-screen alarm · refresh times ──
          const Gap.md(),
          _SectionTitle('notif.generalSection'.tr()),
          SelayaCard(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.xs),
            child: Column(
              children: [
                _SpecialToggle(
                  icon: Icons.notifications_active_rounded,
                  label: 'notif.masterToggle'.tr(),
                  desc: 'notif.masterToggleDesc'.tr(),
                  value: ref.watch(prayerAlertsProvider),
                  onChanged: (v) async {
                    await ref.read(prayerAlertsProvider.notifier).set(v);
                    await _reschedule();
                  },
                ),
                // Tam ekran ezan ayarı KALDIRILDI (kullanıcı 2026-06-15) — full
                // screen takeover yok; ezan sesi normal bildirim/native ile çalar.
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _refreshing
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: context.colors.gold),
                        )
                      : Icon(AppIcons.refresh, color: context.colors.gold),
                  title: Text('notif.refreshTimes'.tr(),
                      style: Theme.of(context).textTheme.titleSmall),
                  subtitle: Text('notif.refreshTimesDesc'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textTertiary)),
                  onTap: _refreshing ? null : _refreshTimes,
                ),
              ],
            ),
          ),
          if (Platform.isAndroid) ...[
            const Gap.md(),
            SelayaCard(
              child: Row(
                children: [
                  Icon(AppIcons.notification, color: context.colors.gold, size: 20),
                  const Gap.md(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('notif.ongoing'.tr(),
                            style: Theme.of(context).textTheme.titleSmall),
                        Text('notif.ongoingDesc'.tr(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.colors.textTertiary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: ongoing,
                    onChanged: (v) async {
                      await ref.read(ongoingNotificationProvider.notifier).set(v);
                      if (v && !perms.notifications) await _requestPermission();
                      await _reschedule();
                    },
                  ),
                ],
              ),
            ),
          ],

          // ── Titreşim & LED ──
          const Gap.lg(),
          SelayaCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.vibration_rounded,
                        color: context.colors.gold, size: 20),
                    const Gap.md(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('notif.vibration'.tr(),
                              style: Theme.of(context).textTheme.titleSmall),
                          Text('notif.vibrationDesc'.tr(),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                      color: context.colors.textTertiary)),
                        ],
                      ),
                    ),
                    Switch(
                      value: prayerVibration,
                      onChanged: (v) => _applyChannelPref(vibration: v),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Special-day notifications (kandil, Cuma, Ramazan) ──
          const Gap.lg(),
          _SectionTitle('notif.specialSection'.tr()),
          SelayaCard(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.xs),
            child: Column(
              children: [
                _SpecialToggle(
                  icon: Icons.nightlight_round,
                  label: 'notif.kandil'.tr(),
                  desc: 'notif.kandilDesc'.tr(),
                  value: ref.watch(kandilNotifProvider),
                  onChanged: (v) async {
                    await ref.read(kandilNotifProvider.notifier).set(v);
                    await ref.read(specialSchedulerProvider).rescheduleSpecial();
                  },
                ),
                _SpecialToggle(
                  icon: Icons.event_available,
                  label: 'notif.cuma'.tr(),
                  desc: 'notif.cumaDesc'.tr(),
                  value: ref.watch(cumaNotifProvider),
                  onChanged: (v) async {
                    await ref.read(cumaNotifProvider.notifier).set(v);
                    await ref.read(specialSchedulerProvider).rescheduleSpecial();
                  },
                ),
                const _RamadanModeRow(),
              ],
            ),
          ),

          // ── At-time alerts ──
          const Gap.lg(),
          _SectionTitle('notif.atTimeSection'.tr()),
          SelayaCard(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final slot in PrayerSlot.values)
                  _AtTimeRow(slot: slot, alarm: config.alarmFor(slot)),
              ],
            ),
          ),

          // ── Before-time reminders ──
          const Gap.lg(),
          _SectionTitle('notif.beforeSection'.tr()),
          SelayaCard(
            child: Column(
              children: [
                for (final slot in PrayerSlot.values)
                  _BeforeTile(slot: slot, alarm: config.alarmFor(slot)),
              ],
            ),
          ),

          // ── "Bildirimler gelmiyor mu?" güvenilirlik rehberi ──
          const Gap.lg(),
          if (Platform.isAndroid) ...[
            const Gap.md(),
            _ReliabilityGuideCard(
              allGranted: perms.notifications &&
                  perms.exactAlarm &&
                  perms.batteryExempt,
              ongoingOn: ongoing,
              onOpenAppSettings: () =>
                  ref.read(permissionServiceProvider).openSettings(),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── at-time row
class _AtTimeRow extends ConsumerWidget {
  final PrayerSlot slot;
  final PrayerAlarm alarm;
  const _AtTimeRow({required this.slot, required this.alarm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(slot.icon, color: c.gold, size: 20),
          const Gap.md(),
          Expanded(
            child: Text(slot.labelKey.tr(),
                style: Theme.of(context).textTheme.titleSmall),
          ),
          if (alarm.atTime)
            _SoundChip(
              sound: alarm.atTimeSound,
              onTap: () => _pickSound(context, ref, alarm.atTimeSound,
                  (s) => ref
                      .read(prayerNotificationProvider.notifier)
                      .setAtTimeSound(slot, s)),
            ),
          Switch(
            value: alarm.atTime,
            onChanged: (v) async {
              await ref
                  .read(prayerNotificationProvider.notifier)
                  .toggleAtTime(slot, v);
              await ref.read(prayerSchedulerProvider).rescheduleAll();
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── before tile
class _BeforeTile extends ConsumerWidget {
  final PrayerSlot slot;
  final PrayerAlarm alarm;
  const _BeforeTile({required this.slot, required this.alarm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ctrl = ref.read(prayerNotificationProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(slot.icon, color: c.gold, size: 20),
            const Gap.md(),
            Expanded(
              child: Text(slot.labelKey.tr(),
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            if (alarm.beforeEnabled)
              _SoundChip(
                sound: alarm.beforeSound,
                onTap: () => _pickSound(context, ref, alarm.beforeSound,
                    (s) => ctrl.setBeforeSound(slot, s)),
              ),
            Switch(
              value: alarm.beforeEnabled,
              onChanged: (v) async {
                await ctrl.toggleBefore(slot, v);
                await ref.read(prayerSchedulerProvider).rescheduleAll();
              },
            ),
          ],
        ),
        if (alarm.beforeEnabled)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4, bottom: 10, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child:
                      Icon(Icons.alarm_rounded, size: 17, color: c.textTertiary),
                ),
                const Gap.sm(),
                // Yan yana, çoklu seçilebilir küçük chip'ler (birden fazla
                // "vakitten önce" hatırlatma seçilebilir).
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final m in _offsetChoices)
                        _OffsetChip(
                          minutes: m,
                          selected: alarm.beforeOffsets.contains(m),
                          onTap: () async {
                            await ctrl.toggleBeforeOffset(slot, m);
                            await ref
                                .read(prayerSchedulerProvider)
                                .rescheduleAll();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
      ],
    );
  }
}

/// Küçük, yan yana, çoklu seçilebilir "vakitten önce" dakika chip'i.
class _OffsetChip extends StatelessWidget {
  final int minutes;
  final bool selected;
  final VoidCallback onTap;
  const _OffsetChip(
      {required this.minutes, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.gold : c.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: selected ? c.gold : c.gold.withValues(alpha: 0.35)),
        ),
        child: Text('$minutes dk',
            style: TextStyle(
                color: selected ? c.onGold : c.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ),
    );
  }
}

class _SoundChip extends StatelessWidget {
  final AdhanSound sound;
  final VoidCallback onTap;
  const _SoundChip({required this.sound, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sound.isSilent ? AppIcons.volumeOff : AppIcons.volumeHigh,
                size: 15, color: c.textSecondary),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(_soundName(sound),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

void _pickSound(BuildContext context, WidgetRef ref, AdhanSound current,
    ValueChanged<AdhanSound> onPick) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MuezzinSheet(
      current: current,
      onPick: (s) async {
        onPick(s);
        await ref.read(prayerSchedulerProvider).rescheduleAll();
      },
    ),
  );
}

// ───────────────────────────────────────────────────────── muezzin picker
class _MuezzinSheet extends StatefulWidget {
  final AdhanSound current;
  final ValueChanged<AdhanSound> onPick;
  const _MuezzinSheet({required this.current, required this.onPick});

  @override
  State<_MuezzinSheet> createState() => _MuezzinSheetState();
}

class _MuezzinSheetState extends State<_MuezzinSheet> {
  final AudioPlayer _preview = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    // Reset the row's play/pause state once a preview finishes, otherwise the
    // icon would stay stuck on "pause" forever.
    _stateSub = _preview.playerStateStream.listen((st) {
      if (mounted && st.processingState == ProcessingState.completed) {
        setState(() => _playingId = null);
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _preview.dispose();
    super.dispose();
  }

  /// Toggle a muezzin preview: tapping the row that's playing pauses it; any
  /// other row stops the current preview and starts that one.
  Future<void> _toggle(AdhanSound s) async {
    if (s.assetPath == null) return;
    if (_playingId == s.id) {
      await _preview.pause();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = s.id);
    try {
      await _preview.setAsset(s.assetPath!);
      await _preview.play();
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final order = [
      AdhanSound.silent,
      AdhanSound.defaultTone,
      AdhanSound.chime,
      ...AdhanSound.muezzins,
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Text('notif.chooseSound'.tr(),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in order)
                    ListTile(
                      leading: _Avatar(sound: s),
                      title: Text(_soundName(s)),
                      trailing: s == widget.current
                          ? Icon(AppIcons.checkCircle, color: c.gold)
                          : (s.assetPath != null
                              ? IconButton(
                                  icon: Icon(
                                      _playingId == s.id
                                          ? AppIcons.pause
                                          : AppIcons.play,
                                      color: c.gold),
                                  onPressed: () => _toggle(s),
                                )
                              : null),
                      onTap: () {
                        widget.onPick(s);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final AdhanSound sound;
  const _Avatar({required this.sound});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (sound.isSilent) {
      return CircleAvatar(
          backgroundColor: c.surface,
          child: Icon(AppIcons.volumeOff, size: 18, color: c.textTertiary));
    }
    if (sound.properName == null) {
      return CircleAvatar(
          backgroundColor: c.gold.withValues(alpha: 0.15),
          child: Icon(AppIcons.notification, size: 18, color: c.gold));
    }
    // Each muezzin shows their initials so the eight voices are distinguishable.
    final initials = sound.properName!
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join();
    return CircleAvatar(
      backgroundColor: c.gold.withValues(alpha: 0.15),
      child: Text(initials,
          style: TextStyle(
              color: c.gold, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

// ───────────────────────────────────────────────────────── shared bits
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: context.colors.gold)),
      );
}

class _SpecialToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SpecialToggle({
    required this.icon,
    required this.label,
    required this.desc,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, color: c.gold, size: 20),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                Text(desc,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// "Ramazan Modu" selector (auto / always-on / off). Auto turns itself on during
/// the Hijri month of Ramadan; the chip glows gold while the mode is active.
/// Changing it reschedules the special block *and* the prayer alarms (the İmsak
/// "sahur sona erdi" wording depends on it).
class _RamadanModeRow extends ConsumerWidget {
  const _RamadanModeRow();

  String _modeLabel(RamadanMode m) => switch (m) {
        RamadanMode.auto => 'notif.ramadanModeAuto'.tr(),
        RamadanMode.on => 'notif.ramadanModeOn'.tr(),
        RamadanMode.off => 'notif.ramadanModeOff'.tr(),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final mode = ref.watch(ramadanModeProvider);
    final active = ref.watch(ramadanActiveProvider);
    return InkWell(
      borderRadius: AppRadius.rMd,
      onTap: () => _pick(context, ref, mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(Icons.restaurant, color: c.gold, size: 20),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('notif.ramadanMode'.tr(),
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    mode == RamadanMode.auto
                        ? (active
                            ? 'notif.ramadanModeActiveNow'.tr()
                            : 'notif.ramadanModeWaiting'.tr())
                        : 'notif.ramadanModeDesc'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textTertiary),
                  ),
                ],
              ),
            ),
            const Gap.sm(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (active ? c.gold : c.textTertiary).withValues(alpha: 0.16),
                borderRadius: AppRadius.rSm,
              ),
              child: Text(_modeLabel(mode),
                  style: TextStyle(
                      color: active ? c.gold : c.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: c.textTertiary),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context, WidgetRef ref, RamadanMode current) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.base, AppSpacing.lg, AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.restaurant, color: context.colors.gold, size: 20),
                  const Gap.sm(),
                  Text('notif.ramadanMode'.tr(),
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            for (final m in RamadanMode.values)
              ListTile(
                title: Text(_modeLabel(m)),
                subtitle: m == RamadanMode.auto
                    ? Text('notif.ramadanModeAutoDesc'.tr())
                    : null,
                trailing: current == m
                    ? Icon(AppIcons.check, color: context.colors.gold)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(ramadanModeProvider.notifier).set(m);
                  await ref.read(specialSchedulerProvider).rescheduleSpecial();
                  await ref.read(prayerSchedulerProvider).rescheduleAll();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// "Tam Ekran Alarm" açıkken, ekran KİLİTLİYKEN gerçekten tam ekran açılıp
/// açılamayacağını net gösterir: izin varsa yeşil onay, yoksa amber uyarı +
/// "İzin Ver" (dokun → sistem izin sayfası). Tam ekran alarmın tek anlamı
/// kilitliyken çalışması olduğundan bu durum her zaman görünür.
// _FullScreenLockStatus KALDIRILDI — tam ekran ezan kaldırıldı.

/// İzinler kartı — açılır/kapanır; başlıkta durum rozeti. Eksik KRİTİK izin
/// (pil optimizasyonu hariç) varsa amber ⚠, hepsi tamamsa yeşil ✓. Kullanıcı
/// kafası karışmasın diye satırlar varsayılan gizli; tıkla → aç.
class _PermissionsCard extends StatefulWidget {
  final bool hasWarning;
  final List<Widget> rows;
  const _PermissionsCard({required this.hasWarning, required this.rows});
  @override
  State<_PermissionsCard> createState() => _PermissionsCardState();
}

class _PermissionsCardState extends State<_PermissionsCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const amber = Color(0xFFD9A441);
    return SelayaCard(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: AppRadius.rMd,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded,
                      color: widget.hasWarning ? amber : c.gold, size: 20),
                  const Gap.md(),
                  Expanded(
                    child: Text('notif.permissionsTitle'.tr(),
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  _StatusBadge(
                    icon: widget.hasWarning
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    label: (widget.hasWarning
                            ? 'notif.permMissing'
                            : 'notif.permReady')
                        .tr(),
                    color: widget.hasWarning ? amber : c.success,
                  ),
                  const Gap.sm(),
                  Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: c.textTertiary),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const _Divider(),
            ...widget.rows,
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool granted;
  final VoidCallback onGrant;
  const _StatusRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.granted,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, color: c.gold, size: 20),
        const Gap.md(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              if (subtitle != null)
                Text(subtitle!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textTertiary)),
            ],
          ),
        ),
        if (granted)
          Icon(AppIcons.checkCircle, color: c.success, size: 22)
        else
          TextButton(onPressed: onGrant, child: Text('notif.grant'.tr())),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Divider(height: 1, color: context.colors.border),
      );
}

/// "Notifications not arriving?" — explains why aggressive OEMs (Samsung etc.)
/// can drop background prayer alerts and lists the exact steps to fix it, with a
/// shortcut into the app's system settings.
class _ReliabilityGuideCard extends StatelessWidget {
  final bool allGranted;
  final bool ongoingOn;
  final VoidCallback onOpenAppSettings;
  const _ReliabilityGuideCard({
    required this.allGranted,
    required this.ongoingOn,
    required this.onOpenAppSettings,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final steps = [
      'notif.guideStep1'.tr(),
      'notif.guideStep2'.tr(),
      'notif.guideStep3'.tr(),
      'notif.guideStep4'.tr(),
    ];
    return SelayaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.troubleshoot, color: c.gold, size: 20),
              const Gap.md(),
              Expanded(child: Text('notif.guideTitle'.tr(), style: text.titleSmall)),
            ],
          ),
          const Gap.sm(),
          Text('notif.guideIntro'.tr(),
              style: text.bodySmall?.copyWith(color: c.textTertiary)),
          if (!ongoingOn) ...[
            const Gap.md(),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: c.gold.withValues(alpha: 0.10),
                borderRadius: AppRadius.rSm,
              ),
              child: Row(
                children: [
                  Icon(Icons.push_pin_outlined, color: c.gold, size: 18),
                  const Gap.sm(),
                  Expanded(
                    child: Text('notif.guideEnableOngoing'.tr(),
                        style: text.bodySmall),
                  ),
                ],
              ),
            ),
          ],
          const Gap.md(),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ',
                      style: text.bodyMedium
                          ?.copyWith(color: c.gold, fontWeight: FontWeight.w700)),
                  Expanded(child: Text(steps[i], style: text.bodyMedium)),
                ],
              ),
            ),
          const Gap.sm(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenAppSettings,
              icon: const Icon(Icons.settings, size: 18),
              label: Text('notif.guideOpenAppSettings'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
