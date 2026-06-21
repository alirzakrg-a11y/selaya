import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/smart_silent_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_logo.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/permission_dialog.dart';
import '../../hatim/data/hatim_reminder.dart';
import '../../notifications/data/daily_content_controller.dart';
import '../../notifications/data/prayer_scheduler.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../womens_mode/data/womens_mode_controller.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lang = context.langCode;
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final city = ref.watch(selectedCityProvider).value;
    final womens = ref.watch(womensModeProvider);
    final womensCtrl = ref.read(womensModeProvider.notifier);

    return SelayaScaffold(
      title: 'settings.title'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          _SectionTitle('settings.appearance'.tr(),
              icon: Icons.palette_outlined),
          SelayaCard(
            child: Column(
              children: [
                // Language
                Row(
                  children: [
                    Icon(AppIcons.translate, color: c.gold, size: 20),
                    const Gap.md(),
                    Expanded(
                        child: Text('settings.language'.tr(),
                            style: Theme.of(context).textTheme.titleSmall)),
                    _LangToggle(),
                  ],
                ),
                const _DividerLine(),
                // Theme
                Row(
                  children: [
                    Icon(AppIcons.moon, color: c.gold, size: 20),
                    const Gap.md(),
                    Expanded(
                        child: Text('settings.theme'.tr(),
                            style: Theme.of(context).textTheme.titleSmall)),
                    _ThemeToggle(mode: settings.themeMode, onChanged: ctrl.setThemeMode),
                  ],
                ),
                const _DividerLine(),
                // Colour palette (#23): Altın / Yeşil / Mavi / Mor / Gül / Turkuaz
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette_outlined, color: c.gold, size: 20),
                        const Gap.md(),
                        Expanded(
                            child: Text('settings.palette'.tr(),
                                style: Theme.of(context).textTheme.titleSmall)),
                      ],
                    ),
                    const Gap.sm(),
                    _PaletteToggle(
                        palette: settings.palette, onChanged: ctrl.setPalette),
                  ],
                ),
                const _DividerLine(),
                // AMOLED
                _SwitchRow(
                  icon: AppIcons.moon,
                  label: 'settings.amoled'.tr(),
                  value: settings.amoled,
                  onChanged: ctrl.setAmoled,
                ),
                const _DividerLine(),
                // Font size (#22): senior-friendly large-text mode.
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.format_size_rounded, color: c.gold, size: 20),
                      const Gap.md(),
                      Expanded(
                          child: Text('settings.fontSize'.tr(),
                              style: Theme.of(context).textTheme.titleSmall)),
                    ],
                  ),
                ),
                _FontSizeSelector(
                    value: settings.textScale, onChanged: ctrl.setTextScale),
              ],
            ),
          ),
          const Gap.lg(),
          _SectionTitle('settings.prayerSettings'.tr(),
              icon: Icons.mosque_rounded),
          SelayaCard(
            child: Column(
              children: [
                _NavRow(
                  icon: AppIcons.location,
                  label: 'settings.location'.tr(),
                  value: city?.name(lang) ?? '—',
                  onTap: () => context.push(Routes.citySelect),
                ),
                const _DividerLine(),
                _NavRow(
                  icon: AppIcons.calculator,
                  label: 'settings.calculationMethod'.tr(),
                  value: settings.calcMethod.label(lang),
                  onTap: () => _pickMethod(context, ref, settings.calcMethod),
                ),
              ],
            ),
          ),
          const Gap.lg(),
          _SectionTitle('settings.fineTune'.tr(), icon: Icons.tune_rounded),
          SelayaCard(
            child: Column(
              children: [
                _NavRow(
                  icon: AppIcons.tune,
                  label: 'settings.minuteOffset'.tr(),
                  value: settings.offsets.isEmpty
                      ? '—'
                      : '${settings.offsets.length}',
                  onTap: () => _editOffsets(context, ref),
                ),
                const _DividerLine(),
                _NavRow(
                  icon: AppIcons.calendar,
                  label: 'settings.hijriOffset'.tr(),
                  value: 'calendar.daysLeft'
                      .tr(args: [_signedNum(settings.hijriOffsetDays)]),
                  onTap: () => _editHijri(context, ref),
                ),
                const _DividerLine(),
                _SwitchRow(
                  icon: AppIcons.asr,
                  label: 'settings.asrHanafi'.tr(),
                  subtitle: 'settings.asrHanafiDesc'.tr(),
                  value: settings.hanafiAsr,
                  onChanged: ctrl.setHanafiAsr,
                ),
              ],
            ),
          ),
          const Gap.lg(),
          _SectionTitle('settings.notifications'.tr(),
              icon: Icons.notifications_outlined),
          SelayaCard(
            child: Column(
              children: [
                _NavRow(
                  icon: AppIcons.notification,
                  label: 'notif.title'.tr(),
                  value: '',
                  onTap: () => context.push(Routes.notificationSettings),
                ),
                const _DividerLine(),
                _DailyNotifToggle(
                  titleKey: 'settings.ayahNotif',
                  descKey: 'settings.ayahNotifDesc',
                  read: (ref) => ref.watch(dailyAyahNotifProvider),
                  write: (ref, lang, on) async {
                    await ref.read(dailyAyahNotifProvider.notifier).set(on);
                    await applyDailyAyah(ref, lang, on);
                  },
                ),
                const _DividerLine(),
                _DailyNotifToggle(
                  titleKey: 'settings.hadithNotif',
                  descKey: 'settings.hadithNotifDesc',
                  read: (ref) => ref.watch(dailyHadithNotifProvider),
                  write: (ref, lang, on) async {
                    await ref.read(dailyHadithNotifProvider.notifier).set(on);
                    await applyDailyHadith(ref, lang, on);
                  },
                ),
                const _DividerLine(),
                const _HatimReminderRow(),
              ],
            ),
          ),
          const Gap.lg(),
          _SectionTitle('settings.smartSilent'.tr(),
              icon: Icons.volume_off_rounded),
          SelayaCard(
            child: _SwitchRow(
              icon: AppIcons.mute,
              label: 'settings.smartSilent'.tr(),
              subtitle: 'settings.smartSilentDesc'.tr(),
              value: settings.smartSilent,
              onChanged: (v) async {
                await ctrl.setSmartSilent(v);
                final svc = ref.read(smartSilentServiceProvider);
                // Muting the ringer needs DND / notification-policy access;
                // send the user to grant it the first time they enable this.
                if (v && !await svc.hasAccess()) {
                  await svc.requestAccess();
                }
                await ref.read(prayerSchedulerProvider).rescheduleAll();
              },
            ),
          ),
          const Gap.lg(),
          _SectionTitle('tracking.title'.tr(),
              icon: Icons.check_circle_outline_rounded),
          const SelayaCard(child: _CheckinToggleRow()),
          const Gap.lg(),
          _SectionTitle('womens.title'.tr(), icon: Icons.female_rounded),
          SelayaCard(
            child: Column(
              children: [
                _SwitchRow(
                  icon: AppIcons.female,
                  label: 'womens.enable'.tr(),
                  subtitle: 'womens.desc'.tr(),
                  value: womens.enabled,
                  onChanged: womensCtrl.setEnabled,
                ),
                if (womens.enabled) ...[
                  const _DividerLine(),
                  _NavRow(
                    icon: AppIcons.calendar,
                    label: 'womens.addPeriod'.tr(),
                    value: '${womens.periods.length}',
                    onTap: () => _addPeriod(context, ref),
                  ),
                  for (var i = 0; i < womens.periods.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(AppIcons.moon, size: 16, color: c.textTertiary),
                          const Gap.sm(),
                          Expanded(
                            child: Text(
                              '${_fmtDate(womens.periods[i].start)} – ${_fmtDate(womens.periods[i].end)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: c.textSecondary),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(AppIcons.close,
                                size: 18, color: c.textTertiary),
                            onPressed: () => womensCtrl.removePeriod(i),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const Gap.lg(),
          _SectionTitle('settings.about'.tr(),
              icon: Icons.info_outline_rounded),
          SelayaCard(
            onTap: () => _showAbout(context),
            child: Row(
              children: [
                const SelayaLogo(size: 44, showWordmark: false),
                const Gap.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('common.appName'.tr(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: c.gold, fontWeight: FontWeight.w700)),
                      const Gap.xs(),
                      Text('common.slogan'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
                const Gap.sm(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: c.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snap) => Text(
                        'v${snap.data?.version ?? '…'}',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                                color: c.gold, fontWeight: FontWeight.w700)),
                  ),
                ),
                const Gap.xs(),
                Icon(AppIcons.forward, size: 16, color: c.textTertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pickMethod(BuildContext context, WidgetRef ref, CalcMethod current) {
    final lang = context.langCode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                    AppSpacing.base, AppSpacing.base, AppSpacing.sm),
                child: Text('settings.calculationMethod'.tr(),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in CalcMethod.values)
                      ListTile(
                        title: Text(m.label(lang)),
                        trailing: m == current
                            ? Icon(AppIcons.check, color: context.colors.gold)
                            : null,
                        onTap: () {
                          ref.read(settingsProvider.notifier).setCalcMethod(m);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editOffsets(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Consumer(builder: (context, ref, _) {
          final s = ref.watch(settingsProvider);
          final ctrl = ref.read(settingsProvider.notifier);
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    children: [
                      Text('settings.minuteOffset'.tr(),
                          style: Theme.of(context).textTheme.titleMedium),
                      const Gap.xs(),
                      Text('settings.minuteOffsetDesc'.tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.colors.textTertiary)),
                    ],
                  ),
                ),
                for (final slot in PrayerSlot.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(slot.labelKey.tr(),
                                style: Theme.of(context).textTheme.titleSmall)),
                        _StepperButton(
                            icon: AppIcons.remove,
                            onTap: () => ctrl.setOffset(slot,
                                (s.offsetFor(slot) - 1).clamp(-30, 30))),
                        SizedBox(
                          width: 54,
                          child: Text(_signedNum(s.offsetFor(slot)),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: context.colors.gold)),
                        ),
                        _StepperButton(
                            icon: AppIcons.add,
                            onTap: () => ctrl.setOffset(slot,
                                (s.offsetFor(slot) + 1).clamp(-30, 30))),
                      ],
                    ),
                  ),
                const Gap.lg(),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _editHijri(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Consumer(builder: (context, ref, _) {
          final s = ref.watch(settingsProvider);
          final ctrl = ref.read(settingsProvider.notifier);
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('settings.hijriOffset'.tr(),
                    style: Theme.of(context).textTheme.titleMedium),
                const Gap.xs(),
                Text('settings.hijriOffsetDesc'.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.colors.textTertiary)),
                const Gap.lg(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepperButton(
                        icon: AppIcons.remove,
                        onTap: () => ctrl
                            .setHijriOffset((s.hijriOffsetDays - 1).clamp(-3, 3))),
                    SizedBox(
                      width: 110,
                      child: Text(
                          'calendar.daysLeft'
                              .tr(args: [_signedNum(s.hijriOffsetDays)]),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    _StepperButton(
                        icon: AppIcons.add,
                        onTap: () => ctrl
                            .setHijriOffset((s.hijriOffsetDays + 1).clamp(-3, 3))),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  static String _signedNum(int n) => n > 0 ? '+$n' : '$n';

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _addPeriod(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
          start: now, end: now.add(const Duration(days: 6))),
    );
    if (range != null) {
      await ref.read(womensModeProvider.notifier).addPeriod(range);
    }
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AboutSheet(),
    );
  }
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  Future<void> _shareApp() async {
    await SharePlus.instance.share(ShareParams(text: 'settings.shareAppText'.tr()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
          MediaQuery.viewPaddingOf(context).bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          const Gap.lg(),
          const SelayaLogo(size: 76, showWordmark: false),
          const Gap.md(),
          Text('common.appName'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: c.gold, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const Gap.xs(),
          Text('common.slogan'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textSecondary)),
          const Gap.sm(),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final v = snap.hasData
                  ? '${snap.data!.version} (${snap.data!.buildNumber})'
                  : '1.0.0';
              return Text('${'settings.version'.tr()} $v',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: c.textTertiary));
            },
          ),
          const Gap.lg(),
          Text('settings.aboutDesc'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textSecondary, height: 1.5)),
          const Gap.lg(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shareApp,
              icon: const Icon(AppIcons.share, size: 18),
              label: Text('settings.shareApp'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.gold,
                side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const Gap.sm(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }
}

class _LangToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = context.locale.languageCode;
    Widget chip(String code, String label) {
      final sel = current == code;
      return GestureDetector(
        onTap: () => context.setLocale(Locale(code)),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: sel ? c.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(label,
              style: TextStyle(
                  color: sel ? c.onGold : c.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(99)),
      child: Row(children: [chip('tr', 'TR'), chip('en', 'EN')]),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final modes = {
      ThemeMode.dark: AppIcons.moon,
      ThemeMode.light: AppIcons.dhuhr,
      ThemeMode.system: AppIcons.settings,
    };
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(99)),
      child: Row(
        children: [
          for (final e in modes.entries)
            GestureDetector(
              onTap: () => onChanged(e.key),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: mode == e.key ? c.gold : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(e.value,
                    size: 16,
                    color: mode == e.key
                        ? c.onGold
                        : c.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Colour-palette picker (#23): Altın (gold) vs İslami Yeşil. Two compact pills
/// with a colour swatch; the active one is gold-bordered. Independent of the
/// light/dark/AMOLED mode.
class _PaletteToggle extends StatelessWidget {
  final AppPalette palette;
  final ValueChanged<AppPalette> onChanged;
  const _PaletteToggle({required this.palette, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget chip(AppPalette p, Color swatch, String label) {
      final sel = palette == p;
      return GestureDetector(
        onTap: () => onChanged(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? c.gold.withValues(alpha: 0.16) : c.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
                color: sel ? c.gold : c.border, width: sel ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration:
                    BoxDecoration(color: swatch, shape: BoxShape.circle),
              ),
              const Gap.xs(),
              Text(label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: sel ? c.gold : c.textSecondary,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(AppPalette.gold, AppColors.gold, 'settings.paletteGold'.tr()),
        chip(AppPalette.green, const Color(0xFF2A6043),
            'settings.paletteGreen'.tr()),
        chip(AppPalette.blue, const Color(0xFF5E8BD0),
            'settings.paletteBlue'.tr()),
        chip(AppPalette.purple, const Color(0xFF9F77D4),
            'settings.palettePurple'.tr()),
        chip(AppPalette.rose, const Color(0xFFD17C95),
            'settings.paletteRose'.tr()),
        chip(AppPalette.teal, const Color(0xFF3FB5A4),
            'settings.paletteTeal'.tr()),
      ],
    );
  }
}

/// Font-size picker (#22): four "A" tiles from small to extra-large. Senior
/// users tap the size they read comfortably; applied app-wide via MediaQuery.
class _FontSizeSelector extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _FontSizeSelector({required this.value, required this.onChanged});

  static const _opts = <(double, String, double)>[
    (0.9, 'settings.fontSmall', 13),
    (1.0, 'settings.fontNormal', 16),
    (1.15, 'settings.fontLarge', 20),
    (1.3, 'settings.fontXLarge', 24),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (var i = 0; i < _opts.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(_opts[i].$1),
              child: () {
                final sel = (value - _opts[i].$1).abs() < 0.001;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? c.gold.withValues(alpha: 0.16) : c.surface,
                    borderRadius: AppRadius.rMd,
                    border: Border.all(
                        color: sel ? c.gold : c.border, width: sel ? 1.5 : 1),
                  ),
                  child: Column(
                    children: [
                      Text('A',
                          style: TextStyle(
                              fontSize: _opts[i].$3,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              color: sel ? c.gold : c.textSecondary)),
                      const Gap.xs(),
                      Text(_opts[i].$2.tr(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: sel ? c.gold : c.textTertiary)),
                    ],
                  ),
                );
              }(),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  const _SectionTitle(this.title, {this.icon});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: c.gold),
            const Gap.xs(),
          ],
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: c.gold)),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Divider(height: 1, color: context.colors.border),
      );
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
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
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _NavRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: c.gold, size: 20),
          const Gap.md(),
          // Label on top + the current value below it (gold), so long values
          // like "Diyanet İşleri Başkanlığı (Türkiye)" wrap instead of overflowing.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                if (value.isNotEmpty) ...[
                  const Gap.xs(),
                  Text(value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.gold)),
                ],
              ],
            ),
          ),
          const Gap.sm(),
          Icon(AppIcons.forward, size: 16, color: c.textTertiary),
        ],
      ),
    );
  }
}

/// A persisted daily-content notification switch (verse / hadith). Its on/off is
/// read via [read] (a persisted provider) so it survives restarts; enabling first
/// requests notification permission, then [write] persists the choice + schedules
/// (or cancels) the notification.
class _DailyNotifToggle extends ConsumerStatefulWidget {
  const _DailyNotifToggle({
    required this.titleKey,
    required this.descKey,
    required this.read,
    required this.write,
  });
  final String titleKey;
  final String descKey;
  final bool Function(WidgetRef ref) read;
  final Future<void> Function(WidgetRef ref, String lang, bool on) write;

  @override
  ConsumerState<_DailyNotifToggle> createState() => _DailyNotifToggleState();
}

class _DailyNotifToggleState extends ConsumerState<_DailyNotifToggle> {
  bool _busy = false;

  Future<void> _toggle(bool v) async {
    final lang = context.langCode;
    if (!v) {
      await widget.write(ref, lang, false);
      return;
    }
    setState(() => _busy = true);
    try {
      final perms = ref.read(permissionServiceProvider);
      final outcome = await perms.requestNotifications();
      if (!outcome.isGranted) {
        if (outcome.needsSettings && mounted) {
          await showOpenSettingsDialog(context, perms,
              title: 'notif.permissionDeniedTitle'.tr(),
              message: 'notif.permissionDeniedBody'.tr());
        }
        return;
      }
      await widget.write(ref, lang, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = widget.read(ref);
    return Row(
      children: [
        Icon(AppIcons.notification, color: c.gold, size: 20),
        const Gap.md(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.titleKey.tr(),
                  style: Theme.of(context).textTheme.titleSmall),
              Text(widget.descKey.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textTertiary)),
            ],
          ),
        ),
        _busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.gold))
            : Switch(value: value, onChanged: _toggle),
      ],
    );
  }
}

/// Hatim Hatırlatması: açık/kapalı + saat seçici (varsayılan 21:00, kapalı).
class _HatimReminderRow extends ConsumerStatefulWidget {
  const _HatimReminderRow();
  @override
  ConsumerState<_HatimReminderRow> createState() => _HatimReminderRowState();
}

class _HatimReminderRowState extends ConsumerState<_HatimReminderRow> {
  bool _busy = false;

  Future<void> _toggle(bool v) async {
    final lang = context.langCode;
    if (!v) {
      await ref.read(hatimReminderProvider.notifier).set(false);
      await applyHatimReminder(ref, lang);
      return;
    }
    setState(() => _busy = true);
    try {
      final perms = ref.read(permissionServiceProvider);
      final outcome = await perms.requestNotifications();
      if (!outcome.isGranted) {
        if (outcome.needsSettings && mounted) {
          await showOpenSettingsDialog(context, perms,
              title: 'notif.permissionDeniedTitle'.tr(),
              message: 'notif.permissionDeniedBody'.tr());
        }
        return;
      }
      await ref.read(hatimReminderProvider.notifier).set(true);
      await applyHatimReminder(ref, lang);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final (h, m) = parseHm(ref.read(hatimReminderTimeProvider));
    final picked = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: h, minute: m));
    if (picked != null) {
      final hm =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await ref.read(hatimReminderTimeProvider.notifier).set(hm);
      if (mounted) await applyHatimReminder(ref, context.langCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = ref.watch(hatimReminderProvider);
    final hm = ref.watch(hatimReminderTimeProvider);
    return Column(
      children: [
        Row(
          children: [
            Icon(AppIcons.notification, color: c.gold, size: 20),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('settings.hatimReminder'.tr(),
                      style: Theme.of(context).textTheme.titleSmall),
                  Text('settings.hatimReminderDesc'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textTertiary)),
                ],
              ),
            ),
            _busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold))
                : Switch(value: on, onChanged: _toggle),
          ],
        ),
        if (on) ...[
          const Gap.sm(),
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xs, horizontal: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, color: c.textSecondary, size: 18),
                  const Gap.sm(),
                  Expanded(
                    child: Text('settings.hatimReminderTime'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  Text(hm,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: c.gold, fontWeight: FontWeight.w700)),
                  Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, size: 18, color: c.gold),
      ),
    );
  }
}

/// "Namazı kıldın mı?" sorusunu aç/kapa (vakitten ~20 dk sonra çıkan check-in).
/// Tercih prefs'te tutulur; kapalıyken pendingPrayerCheckIn hiç sormaz.
class _CheckinToggleRow extends ConsumerStatefulWidget {
  const _CheckinToggleRow();
  @override
  ConsumerState<_CheckinToggleRow> createState() => _CheckinToggleRowState();
}

class _CheckinToggleRowState extends ConsumerState<_CheckinToggleRow> {
  late bool _on = ref
          .read(sharedPreferencesProvider)
          .getBool(PrefKeys.checkinPrompt) ??
      true;

  @override
  Widget build(BuildContext context) => _SwitchRow(
        icon: Icons.task_alt_rounded,
        label: 'settings.checkinPrompt'.tr(),
        subtitle: 'settings.checkinPromptDesc'.tr(),
        value: _on,
        onChanged: (v) {
          setState(() => _on = v);
          ref.read(sharedPreferencesProvider).setBool(PrefKeys.checkinPrompt, v);
        },
      );
}
