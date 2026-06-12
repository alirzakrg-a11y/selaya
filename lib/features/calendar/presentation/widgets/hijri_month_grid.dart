import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// A reusable Gregorian month grid (weeks start Monday) with weekday headers.
/// Each in-month day is rendered by [cellBuilder] as a square cell, so callers
/// (fasting tracker, calendar) can show their own content (Hijri day, status…).
class HijriMonthGrid extends StatelessWidget {
  final int year;
  final int month; // 1-12
  final String lang;
  final Widget Function(DateTime day) cellBuilder;
  const HijriMonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.lang,
    required this.cellBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leading = (first.weekday - 1) % 7; // blanks before day 1 (Mon-start)

    // 2024-01-01 was a Monday → use it to label weekday headers.
    final headerStart = DateTime(2024, 1, 1);
    final headers = [
      for (var i = 0; i < 7; i++)
        Expanded(
          child: Center(
            child: Text(
              DateFormat('E', lang)
                  .format(headerStart.add(Duration(days: i))),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.textTertiary),
            ),
          ),
        ),
    ];

    final items = <Widget?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth; d++) cellBuilder(DateTime(year, month, d)),
    ];
    while (items.length % 7 != 0) {
      items.add(null);
    }

    final rows = <Widget>[];
    for (var r = 0; r < items.length; r += 7) {
      rows.add(Row(
        children: [
          for (var k = 0; k < 7; k++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: items[r + k] ?? const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ));
    }

    return Column(
      children: [
        Row(children: headers),
        const Gap.sm(),
        ...rows,
      ],
    );
  }
}
