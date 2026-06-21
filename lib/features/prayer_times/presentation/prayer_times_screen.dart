import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gold_icon.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/states.dart';
import '../../notifications/data/prayer_notification_controller.dart';
import '../../notifications/data/prayer_scheduler.dart';
import '../data/prayer_repository.dart';
import '../domain/prayer.dart';
import 'widgets/extended_times_section.dart';
import 'widgets/next_prayer_card.dart';
import 'widgets/prayer_clock_dial.dart';

class PrayerTimesScreen extends ConsumerStatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  ConsumerState<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends ConsumerState<PrayerTimesScreen> {
  Future<void> _toggleNotify(PrayerSlot slot, bool current) async {
    if (!current) {
      await ref.read(notificationServiceProvider).requestPermission();
    }
    await ref
        .read(prayerNotificationProvider.notifier)
        .toggleAtTime(slot, !current);
    await ref.read(prayerSchedulerProvider).rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    final times = ref.watch(dailyTimesProvider);
    final view = ref.watch(prayerViewProvider).value;
    final config = ref.watch(prayerNotificationProvider);

    return SelayaScaffold(
      title: 'prayer.title'.tr(),
      actions: [
        IconButton(
          icon: const Icon(AppIcons.settings),
          onPressed: () => context.push(Routes.settings),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          _DatePill(onTap: () => context.push(Routes.citySelect)),
          const Gap.md(),
          const NextPrayerCard(),
          const Gap.md(),
          // Hızlı erişim: İmsakiye + Bildirim Ayarları (kullanıcı isteği).
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.wb_twilight_rounded,
                  label: 'imsakiye.title'.tr(),
                  onTap: () => context.push(Routes.imsakiye),
                ),
              ),
              const Gap.sm(),
              Expanded(
                child: _QuickAction(
                  icon: AppIcons.notification,
                  label: 'notif.title'.tr(),
                  onTap: () => context.push(Routes.notificationSettings),
                ),
              ),
            ],
          ),
          const Gap.lg(),
          times.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl), child: SelayaLoading()),
            error: (e, _) => SelayaError(error: e),
            data: (t) => Column(
              children: [
                for (final slot in PrayerSlot.values)
                  _PrayerRow(
                    slot: slot,
                    time: t.timeOf(slot),
                    active: slot == view?.currentSlot,
                    notify: config.alarmFor(slot).atTime,
                    onToggle: slot.isPrayer
                        ? () => _toggleNotify(
                            slot, config.alarmFor(slot).atTime)
                        : null,
                  ),
              ],
            ),
          ),
          const Gap.lg(),
          const PrayerClockDial(),
          const Gap.lg(),
          const ExtendedTimesSection(),
          const Gap.md(),
          const _KerahatCard(),
          const Gap.md(),
          const _SourceNote(),
        ],
      ),
    );
  }
}

/// Dini içerik için kaynak notu (Diyanet İlmihali esas alınır).
class _SourceNote extends StatelessWidget {
  const _SourceNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.rMd,
        color: c.gold.withValues(alpha: 0.08),
        border: Border.all(color: c.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.gold),
          const Gap.sm(),
          Expanded(
            child: Text(
              'Kaynak: Diyanet İşleri Başkanlığı İlmihali esas alınmıştır. '
              'Ayrıntı için yetkili kaynaklara başvurun.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vakitler ekranındaki hızlı erişim butonu (İmsakiye · Bildirim Ayarları).
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: c.gold),
          const Gap.sm(),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}

class _DatePill extends ConsumerWidget {
  final VoidCallback onTap;
  const _DatePill({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final now = DateTime.now();
    final city = ref.watch(selectedCityProvider).value;
    return SelayaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      child: Row(
        children: [
          const Icon(AppIcons.location, size: 18, color: AppColors.gold),
          const Gap.sm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(city?.name(lang) ?? '—',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                    '${formatGregorian(now, lang)} • ${formatHijri(now, lang, offsetDays: ref.watch(hijriOffsetProvider))}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.colors.textTertiary)),
              ],
            ),
          ),
          const Icon(AppIcons.forward, size: 18),
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  final PrayerSlot slot;
  final DateTime time;
  final bool active;
  final bool notify;
  final VoidCallback? onToggle;
  const _PrayerRow({
    required this.slot,
    required this.time,
    required this.active,
    required this.notify,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.base),
      decoration: BoxDecoration(
        borderRadius: AppRadius.rLg,
        gradient: active ? LinearGradient(colors: c.prayerActive) : null,
        color: active ? null : c.surfaceAlt,
        border: Border.all(
            color: active ? c.gold.withValues(alpha: 0.5) : c.border),
      ),
      child: Row(
        children: [
          GoldIcon(slot.icon, size: 22),
          const Gap.md(),
          Expanded(
            child: Text(slot.labelKey.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: active ? Colors.white : c.textPrimary)),
          ),
          Text(
            formatClock(time),
            style: AppTypography.tabular(
              Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: active ? Colors.white : c.textPrimary,
                  fontWeight: FontWeight.w700),
            ),
          ),
          if (onToggle != null) ...[
            const Gap.sm(),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                notify ? AppIcons.notification : AppIcons.volumeOff,
                size: 20,
                color: notify ? c.gold : c.textTertiary,
              ),
              onPressed: onToggle,
            ),
          ] else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _KerahatCard extends ConsumerWidget {
  const _KerahatCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final windows = ref.watch(extendedTimesProvider).value?.kerahat ?? const [];
    return SelayaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.gold.withValues(alpha: 0.12),
                ),
                child:
                    const Icon(AppIcons.kerahat, color: AppColors.gold, size: 20),
              ),
              const Gap.md(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('prayer.forbiddenTimes'.tr(),
                        style: Theme.of(context).textTheme.titleSmall),
                    Text('prayer.kerahatDesc'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: c.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
          if (windows.isNotEmpty) ...[
            const Gap.sm(),
            for (final w in windows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(w.labelKey.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: c.textSecondary)),
                    ),
                    Text(
                      '${formatClock(w.start)} – ${formatClock(w.end!)}',
                      style: AppTypography.tabular(Theme.of(context)
                          .textTheme
                          .titleSmall!
                          .copyWith(color: c.textPrimary)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
