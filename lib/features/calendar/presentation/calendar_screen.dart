import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../data/religious_days.dart';
import 'religious_day_detail.dart';
import 'widgets/calendar_month_view.dart';

const _hMonthsTr = [
  'Muharrem', 'Safer', 'Rebiülevvel', 'Rebiülahir', 'Cemaziyelevvel',
  'Cemaziyelahir', 'Recep', 'Şaban', 'Ramazan', 'Şevval', 'Zilkade', 'Zilhicce'
];
const _hMonthsEn = [
  'Muharram', 'Safar', 'Rabi I', 'Rabi II', 'Jumada I',
  'Jumada II', 'Rajab', 'Shaban', 'Ramadan', 'Shawwal', 'Dhul-Qadah', 'Dhul-Hijjah'
];

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaScaffold(
      title: 'calendar.title'.tr(),
      showBack: true,
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: c.gold,
              unselectedLabelColor: c.textTertiary,
              indicatorColor: c.gold,
              tabs: [
                Tab(text: 'calendar.religiousDays'.tr()),
                Tab(text: 'calendar.tabMonth'.tr()),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [_ReligiousDaysView(), CalendarMonthView()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Religious-days view: year tabs (e.g. 2025/2026/2027) + Hijri toggle + days
/// grouped by month. Tapping a day opens a shareable greeting card.
class _ReligiousDaysView extends ConsumerStatefulWidget {
  const _ReligiousDaysView();
  @override
  ConsumerState<_ReligiousDaysView> createState() => _ReligiousDaysViewState();
}

class _ReligiousDaysViewState extends ConsumerState<_ReligiousDaysView> {
  late int _year;
  bool _hicri = false;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final now = DateTime.now();
    final all = ref.watch(religiousDaysProvider);
    final offset = ref.watch(hijriOffsetProvider);
    final years = [now.year - 1, now.year, now.year + 1];
    final days = all.where((d) => d.gregorian.year == _year).toList();

    return Column(
      children: [
        _nextHero(context, all, lang, offset, now),
        // year tabs + hijri toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (final y in years)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _YearChip(
                          year: y,
                          selected: y == _year,
                          onTap: () => setState(() => _year = y),
                        ),
                      ),
                  ],
                ),
              ),
              _Toggle(
                hicri: _hicri,
                onTap: () => setState(() => _hicri = !_hicri),
              ),
            ],
          ),
        ),
        Expanded(
          child: days.isEmpty
              ? SelayaEmpty(
                  icon: AppIcons.calendar,
                  message: 'common.empty'.tr(),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0,
                      AppSpacing.base, AppSpacing.xxxl),
                  children: _buildGrouped(context, days, lang, offset, now),
                ),
        ),
      ],
    );
  }

  /// Bugünün hicri tarihi + sıradaki dini güne geri sayım (üst kart).
  Widget _nextHero(BuildContext context, List<CalendarDay> all, String lang,
      int offset, DateTime now) {
    final c = context.colors;
    final tr = lang == 'tr';
    final today = DateTime(now.year, now.month, now.day);
    final h = HijriCalendar.fromDate(
        offset == 0 ? today : today.add(Duration(days: offset)));
    final hijriToday =
        '${h.hDay} ${(tr ? _hMonthsTr : _hMonthsEn)[h.hMonth - 1]} ${h.hYear}';

    CalendarDay? next;
    for (final d in all) {
      final start =
          DateTime(d.gregorian.year, d.gregorian.month, d.gregorian.day);
      final end = start.add(Duration(days: d.days - 1));
      if (!end.isBefore(today)) {
        next = d;
        break;
      }
    }

    final children = <Widget>[
      Row(
        children: [
          Icon(AppIcons.calendar, size: 14, color: c.gold),
          const Gap.xs(),
          Text(tr ? 'Bugün' : 'Today',
              style: TextStyle(
                  color: c.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const Gap.sm(),
          Expanded(
            child: Text('$hijriToday  ·  ${formatGregorian(today, lang)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.textSecondary)),
          ),
        ],
      ),
    ];

    if (next != null) {
      final nx = next;
      final daysLeft = DateTime(
              nx.gregorian.year, nx.gregorian.month, nx.gregorian.day)
          .difference(today)
          .inDays;
      final countdown = daysLeft <= 0
          ? (tr ? 'Bugün' : 'Today')
          : (tr ? '$daysLeft gün kaldı' : 'in $daysLeft days');
      children.add(const Gap.md());
      children.add(InkWell(
        onTap: () => showReligiousDayDetail(context, nx, lang),
        borderRadius: AppRadius.rLg,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.gold.withValues(alpha: 0.16)),
              child: Icon(AppIcons.moon, color: c.gold, size: 20),
            ),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr ? 'SIRADAKİ' : 'NEXT',
                      style: TextStyle(
                          color: c.textTertiary,
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700)),
                  Text(nx.name(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Gap.sm(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: c.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99)),
              child: Text(countdown,
                  style: TextStyle(
                      color: c.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ),
      ));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.md, AppSpacing.base, 0),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.gold.withValues(alpha: 0.18), c.surfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.rXl,
        border: Border.all(color: c.gold.withValues(alpha: 0.25)),
      ),
      child: Column(children: children),
    );
  }

  List<Widget> _buildGrouped(BuildContext context, List<CalendarDay> days,
      String lang, int offset, DateTime now) {
    final c = context.colors;
    final out = <Widget>[];
    int? month;
    for (final d in days) {
      if (d.gregorian.month != month) {
        month = d.gregorian.month;
        out.add(Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.xs,
              out.isEmpty ? AppSpacing.xs : AppSpacing.base, 4, AppSpacing.xs),
          child: Text(DateFormat('MMMM', lang).format(d.gregorian),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: c.gold,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700)),
        ));
      }
      final isToday = d.gregorian.year == now.year &&
          d.gregorian.month == now.month &&
          d.gregorian.day == now.day;
      final past = d.gregorian
          .isBefore(DateTime(now.year, now.month, now.day));
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Opacity(
          opacity: past ? 0.5 : 1,
          child: SelayaCard(
            onTap: () => showReligiousDayDetail(context, d, lang),
            child: Row(
              children: [
                Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: c.gold.withValues(alpha: isToday ? 0.9 : 0.14),
                    borderRadius: AppRadius.rMd,
                  ),
                  child: Column(
                    children: [
                      Text(
                          _hicri
                              ? '${_hijriDay(d, offset)}'
                              : '${d.gregorian.day}',
                          style: TextStyle(
                              color: isToday
                                  ? c.onGold
                                  : c.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      Text(
                          _hicri
                              ? _hijriMonShort(d)
                              : DateFormat('E', lang).format(d.gregorian),
                          style: TextStyle(
                              color: isToday
                                  ? c.onGoldMuted
                                  : c.textTertiary,
                              fontSize: 10)),
                    ],
                  ),
                ),
                const Gap.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name(lang),
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(_hicri ? d.hijri : d.note(lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: c.textTertiary)),
                    ],
                  ),
                ),
                Icon(AppIcons.share, size: 18, color: c.textTertiary),
              ],
            ),
          ),
        ),
      ));
    }
    return out;
  }

  int _hijriDay(CalendarDay d, int offset) {
    // The stored hijri string is "DD MonthName YYYY"; parse the leading number.
    final parts = d.hijri.split(' ');
    return int.tryParse(parts.first) ?? d.gregorian.day;
  }

  String _hijriMonShort(CalendarDay d) {
    final parts = d.hijri.split(' ');
    return parts.length > 1 ? parts[1].substring(0, 3) : '';
  }
}

class _YearChip extends StatelessWidget {
  final int year;
  final bool selected;
  final VoidCallback onTap;
  const _YearChip(
      {required this.year, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.gold : c.surfaceAlt,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? c.gold : c.border),
        ),
        child: Text('$year',
            style: TextStyle(
                color: selected ? c.onGold : c.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool hicri;
  final VoidCallback onTap;
  const _Toggle({required this.hicri, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.calendar, size: 14, color: c.gold),
            const SizedBox(width: 5),
            Text(hicri ? 'calendar.hijri'.tr() : 'calendar.gregorian'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}
