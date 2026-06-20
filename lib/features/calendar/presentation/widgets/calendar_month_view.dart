import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/data/content_providers.dart';
import '../../../../core/localization/localized_text.dart';
import '../../../../core/models/content.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/selaya_card.dart';
import '../../../../core/widgets/states.dart';
import '../../../prayer_times/data/prayer_repository.dart';
import 'hijri_month_grid.dart';

/// Monthly calendar grid that highlights religious days (incl. multi-day spans)
/// and lets the user browse months/years and tap an event for details.
class CalendarMonthView extends ConsumerStatefulWidget {
  const CalendarMonthView({super.key});

  @override
  ConsumerState<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends ConsumerState<CalendarMonthView> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _shift(int delta) {
    setState(() {
      final m = DateTime(_year, _month + delta, 1);
      _year = m.year;
      _month = m.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final offset = ref.watch(hijriOffsetProvider);
    final daysAsync = ref.watch(calendarDaysProvider);
    final now = DateTime.now();

    return daysAsync.when(
      loading: () => const SelayaLoading(),
      error: (e, _) => SelayaError(error: e),
      data: (events) {
        CalendarDay? eventFor(DateTime day) {
          final dd = DateTime(day.year, day.month, day.day);
          for (final e in events) {
            final s = DateTime(
                e.gregorian.year, e.gregorian.month, e.gregorian.day);
            final end = s.add(Duration(days: e.days - 1));
            if (!dd.isBefore(s) && !dd.isAfter(end)) return e;
          }
          return null;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(AppIcons.back, size: 18),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', lang)
                        .format(DateTime(_year, _month)),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.forward, size: 22),
                  onPressed: () => _shift(1),
                ),
              ],
            ),
            const Gap.sm(),
            SelayaCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: HijriMonthGrid(
                year: _year,
                month: _month,
                lang: lang,
                cellBuilder: (day) =>
                    _cell(context, day, eventFor(day), offset, now, lang),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cell(BuildContext context, DateTime day, CalendarDay? event,
      int offset, DateTime now, String lang) {
    final c = context.colors;
    final hijri = HijriCalendar.fromDate(
        offset == 0 ? day : day.add(Duration(days: offset)));
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final highlight = event != null;

    return GestureDetector(
      onTap: highlight ? () => _showEvent(context, event, lang) : null,
      child: Container(
        decoration: BoxDecoration(
          color: highlight
              ? c.gold.withValues(alpha: 0.16)
              : c.surface,
          borderRadius: AppRadius.rSm,
          border: Border.all(
            color: isToday
                ? c.gold
                : (highlight ? c.gold.withValues(alpha: 0.4) : c.border),
            width: isToday ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${day.day}',
                style: TextStyle(
                    color: highlight ? c.gold : c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            Text('${hijri.hDay}',
                style: TextStyle(color: c.textTertiary, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  void _showEvent(BuildContext context, CalendarDay event, String lang) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(AppIcons.moon, color: c.gold),
                  const Gap.sm(),
                  Expanded(
                    child: Text(event.name(lang),
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ],
              ),
              const Gap.xs(),
              Text('${formatGregorian(event.gregorian, lang)} • ${event.hijri}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textTertiary)),
              if (event.note(lang).isNotEmpty) ...[
                const Gap.md(),
                Text(event.note(lang),
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
