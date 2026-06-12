import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/share/share_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../data/religious_days.dart';
import 'widgets/calendar_month_view.dart';

String greetingForDay(CalendarDay d, String lang) {
  final tr = lang == 'tr';
  switch (d.type) {
    case 'kandil':
      return tr
          ? 'Kandiliniz mübarek olsun. Dualarınız kabul olsun.'
          : 'May your holy night be blessed.';
    case 'holiday':
      return tr ? 'Bayramınız mübarek olsun, nice bayramlara.' : 'Eid Mubarak.';
    case 'new_year':
      return tr
          ? 'Hicri yeni yılınız mübarek olsun.'
          : 'Happy Islamic New Year.';
    case 'fast':
      if (d.name('tr').contains('Ramazan')) {
        return tr
            ? 'Hayırlı Ramazanlar. Oruçlarınız kabul olsun.'
            : 'Ramadan Mubarak.';
      }
      return tr ? 'Hayırlı ve bereketli günler.' : 'A blessed day.';
    default:
      return tr ? 'Hayırlı ve bereketli günler.' : 'A blessed day.';
  }
}

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

  void _share(CalendarDay d, String lang) {
    // backgroundImage verilmez → paylaşım sayfası arka planı PANELDEKİ duvar
    // kâğıdı havuzundan rastgele seçer (gömülü asset değil; akışla aynı yol).
    showVerseShareSheet(
      context,
      text: greetingForDay(d, lang),
      reference: formatGregorian(d.gregorian, lang),
      label: d.name(lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final c = context.colors;
    final now = DateTime.now();
    final all = ref.watch(religiousDaysProvider);
    final offset = ref.watch(hijriOffsetProvider);
    final years = [now.year - 1, now.year, now.year + 1];
    final days = all.where((d) => d.gregorian.year == _year).toList();

    return Column(
      children: [
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
              ? Center(
                  child: Text('common.empty'.tr(),
                      style: TextStyle(color: c.textTertiary)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0,
                      AppSpacing.base, AppSpacing.xxxl),
                  children: _buildGrouped(context, days, lang, offset, now),
                ),
        ),
      ],
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
          padding: EdgeInsets.fromLTRB(
              4, out.isEmpty ? AppSpacing.xs : AppSpacing.base, 4, AppSpacing.xs),
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
            onTap: () => _share(d, lang),
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
                                  ? const Color(0xFF1A1203)
                                  : c.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      Text(
                          _hicri
                              ? _hijriMonShort(d)
                              : DateFormat('E', lang).format(d.gregorian),
                          style: TextStyle(
                              color: isToday
                                  ? const Color(0xCC1A1203)
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
                color: selected ? const Color(0xFF1A1203) : c.textSecondary,
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
