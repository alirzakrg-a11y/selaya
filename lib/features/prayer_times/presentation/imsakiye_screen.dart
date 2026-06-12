import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/prayer_repository.dart';
import '../domain/prayer.dart';

/// Tek bir günün tüm namaz vakitleri (imsakiye satırı).
class ImsakDay {
  final DateTime date;
  final DailyPrayerTimes times;
  const ImsakDay(this.date, this.times);
}

/// 60 günlük (≈2 ay) imsakiye — seçili şehir + yönteme göre [computeTimes] ile
/// gün gün hesaplanır (ana Vakitler ekranıyla aynı, güncel kaynak).
final imsakiyeProvider = FutureProvider<List<ImsakDay>>((ref) async {
  final city = await ref.watch(selectedCityProvider.future);
  final settings = ref.watch(settingsProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final out = <ImsakDay>[];
  for (var i = 0; i < 60; i++) {
    final d = start.add(Duration(days: i));
    out.add(ImsakDay(d, computeTimes(city, settings, d)));
  }
  return out;
});

const _vakitler = <(String, IconData)>[
  ('imsak', Icons.nightlight_round),
  ('sunrise', Icons.wb_twilight_rounded),
  ('dhuhr', Icons.wb_sunny_rounded),
  ('asr', Icons.wb_cloudy_rounded),
  ('maghrib', Icons.brightness_4_rounded),
  ('isha', Icons.dark_mode_rounded),
];

class ImsakiyeScreen extends ConsumerStatefulWidget {
  const ImsakiyeScreen({super.key});
  @override
  ConsumerState<ImsakiyeScreen> createState() => _ImsakiyeScreenState();
}

class _ImsakiyeScreenState extends ConsumerState<ImsakiyeScreen> {
  int _dayOffset = 0; // 0 = bugün
  bool _monthly = false;

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  List<DateTime> _times(DailyPrayerTimes t) =>
      [t.imsak, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha];

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final c = context.colors;
    final cityName = ref.watch(selectedCityProvider).value?.name(lang) ?? '';
    final async = ref.watch(imsakiyeProvider);

    return SelayaScaffold(
      title: 'imsakiye.title'.tr(),
      showBack: true,
      actions: [
        async.maybeWhen(
          data: (_) => IconButton(
            tooltip: _monthly
                ? 'imsakiye.daily'.tr()
                : 'imsakiye.monthly'.tr(),
            icon: Icon(_monthly
                ? Icons.calendar_view_day_rounded
                : Icons.calendar_month_rounded),
            color: c.gold,
            onPressed: () => setState(() => _monthly = !_monthly),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (days) {
          final cap = _dayOffset.clamp(0, days.length - 1);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                    AppSpacing.sm, AppSpacing.base, AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 16, color: c.gold),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(cityName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: c.gold, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _monthly
                    ? _table(context, lang, days)
                    : _dayView(context, lang, days, cap),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Tek gün görünümü ──────────────────────────────────────────────────
  Widget _dayView(
      BuildContext context, String lang, List<ImsakDay> days, int idx) {
    final c = context.colors;
    final day = days[idx];
    final times = _times(day.times);
    final now = DateTime.now();
    final isToday = idx == 0;
    final nextIdx =
        isToday ? times.indexWhere((t) => t.isAfter(now)) : -1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.xs, AppSpacing.base, AppSpacing.xxxl),
      children: [
        // Tarih gezgini.
        SelayaCard(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                color: idx > 0 ? c.gold : c.textTertiary,
                onPressed: idx > 0
                    ? () => setState(() => _dayOffset = idx - 1)
                    : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(formatGregorian(day.date, lang),
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(formatWeekday(day.date, lang),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: c.textTertiary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: idx < days.length - 1 ? c.gold : c.textTertiary,
                onPressed: idx < days.length - 1
                    ? () => setState(() => _dayOffset = idx + 1)
                    : null,
              ),
            ],
          ),
        ),
        const Gap.md(),
        // Vakitler (6 satır).
        for (var i = 0; i < _vakitler.length; i++)
          _PrayerRow(
            label: 'imsakiye.${_vakitler[i].$1}'.tr(),
            icon: _vakitler[i].$2,
            time: formatClock(times[i]),
            active: i == nextIdx,
            passed: isToday && nextIdx >= 0 && i < nextIdx,
            onBell: () => context.push(Routes.notificationSettings),
          ),
        const Gap.lg(),
        FilledButton.icon(
          onPressed: () => setState(() => _monthly = true),
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text('imsakiye.monthly'.tr()),
          style: FilledButton.styleFrom(
            backgroundColor: c.gold,
            foregroundColor: const Color(0xFF1A1203),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                const RoundedRectangleBorder(borderRadius: AppRadius.rLg),
          ),
        ),
      ],
    );
  }

  // ── 60 günlük tablo ───────────────────────────────────────────────────
  Widget _table(BuildContext context, String lang, List<ImsakDay> days) {
    final todayKey = _key(DateTime.now());
    return Column(
      children: [
        _headerRow(context),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            itemCount: days.length,
            itemBuilder: (context, i) {
              final d = days[i];
              return _tableRow(context, lang, d, _key(d.date) == todayKey, i);
            },
          ),
        ),
      ],
    );
  }

  Widget _headerRow(BuildContext context) {
    final c = context.colors;
    final st = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: c.textTertiary, fontWeight: FontWeight.w700);
    Widget cell(String key) => Expanded(
        flex: 3,
        child: Text('imsakiye.$key'.tr(),
            textAlign: TextAlign.center, style: st));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('imsakiye.date'.tr(), style: st)),
          cell('imsak'),
          cell('sunrise'),
          cell('dhuhr'),
          cell('asr'),
          cell('maghrib'),
          cell('isha'),
        ],
      ),
    );
  }

  Widget _tableRow(
      BuildContext context, String lang, ImsakDay d, bool isToday, int i) {
    final c = context.colors;
    final times = _times(d.times);
    final ts = TextStyle(
        fontSize: 11.5,
        color: c.textPrimary,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()]);
    Widget time(DateTime v, bool accent) => Expanded(
          flex: 3,
          child: Text(formatClock(v),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: accent
                  ? ts.copyWith(color: c.gold, fontWeight: FontWeight.w800)
                  : ts),
        );
    return Container(
      color: isToday
          ? c.gold.withValues(alpha: 0.14)
          : (i.isEven ? c.surfaceAlt.withValues(alpha: 0.35) : null),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Text(DateFormat('d MMM', lang).format(d.date),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isToday ? c.gold : c.textPrimary)),
                const SizedBox(width: 5),
                Text(formatWeekday(d.date, lang).substring(0, 2),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
          for (var k = 0; k < times.length; k++) time(times[k], k == 0),
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String time;
  final bool active;
  final bool passed;
  final VoidCallback onBell;
  const _PrayerRow({
    required this.label,
    required this.icon,
    required this.time,
    required this.active,
    this.passed = false,
    required this.onBell,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active ? c.gold : (passed ? c.textTertiary : c.textPrimary);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: active
            ? c.gold.withValues(alpha: 0.14)
            : (passed ? c.surface : c.surfaceAlt),
        borderRadius: AppRadius.rLg,
        border: Border.all(
            color: active ? c.gold.withValues(alpha: 0.6) : c.border,
            width: active ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: active
                  ? c.gold
                  : (passed ? c.textTertiary : c.textSecondary),
              size: 22),
          const Gap.md(),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: fg)),
          ),
          Text(time,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
          const Gap.sm(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.notifications_none_rounded,
                size: 20, color: c.textTertiary),
            onPressed: onBell,
          ),
        ],
      ),
    );
  }
}
