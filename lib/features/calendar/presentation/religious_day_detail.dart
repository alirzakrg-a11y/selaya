import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/models/content.dart';
import '../../../core/share/share_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../data/religious_day_info.dart';

/// Bir dini güne/geceye uygun tebrik mesajı (paylaşım için).
String greetingForDay(CalendarDay d, String lang) {
  switch (d.type) {
    case 'kandil':
      return 'xt.rdayGreetingKandil'.tr();
    case 'holiday':
      return 'xt.rdayGreetingHoliday'.tr();
    case 'new_year':
      return 'xt.rdayGreetingNewYear'.tr();
    case 'fast':
      if (d.name('tr').contains('Ramazan')) {
        return 'xt.rdayGreetingRamadan'.tr();
      }
      return 'xt.rdayGreetingBlessedDay'.tr();
    default:
      return 'xt.rdayGreetingBlessedDay'.tr();
  }
}

IconData _typeIcon(String type) => switch (type) {
      'kandil' => AppIcons.moon,
      'holiday' => Icons.celebration_rounded,
      'new_year' => Icons.auto_awesome_rounded,
      'fast' => Icons.nightlight_round,
      _ => AppIcons.calendar,
    };

/// Dini gün detay sayfası — tarih + not + anlamı + tavsiye edilen ibadetler +
/// tebrik paylaş. Hem "Dini Günler" listesi hem ay görünümü kullanır.
void showReligiousDayDetail(
    BuildContext context, CalendarDay day, String lang) {
  final c = context.colors;
  final info = religiousDayInfo[religiousDaySlug(day.id)];

  Widget label(String t) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(t,
            style: TextStyle(
                color: c.gold,
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w700)),
      );

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: info == null ? 0.45 : 0.66,
        maxChildSize: 0.92,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.gold.withValues(alpha: 0.15)),
                  child: Icon(_typeIcon(day.type), color: c.gold, size: 22),
                ),
                const Gap.md(),
                Expanded(
                  child: Text(day.name(lang),
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const Gap.sm(),
            Row(
              children: [
                Icon(AppIcons.calendar, size: 14, color: c.gold),
                const Gap.xs(),
                Expanded(
                  child: Text(
                      '${formatGregorian(day.gregorian, lang)}  ·  ${day.hijri}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textTertiary)),
                ),
              ],
            ),
            if (day.note(lang).isNotEmpty) ...[
              const Gap.md(),
              Text(day.note(lang),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.textSecondary, height: 1.45)),
            ],
            if (info != null) ...[
              const Gap.lg(),
              label('xt.rdaySignificanceLabel'.tr()),
              const Gap.xs(),
              Text(info.significance(lang),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.55)),
              const Gap.lg(),
              label('xt.rdayRecommendedLabel'.tr()),
              const Gap.xs(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: c.gold.withValues(alpha: 0.08),
                  borderRadius: AppRadius.rLg,
                  border: Border.all(color: c.gold.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: c.gold),
                    const Gap.sm(),
                    Expanded(
                      child: Text(info.amel(lang),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: c.textSecondary, height: 1.5)),
                    ),
                  ],
                ),
              ),
            ],
            const Gap.lg(),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                showVerseShareSheet(
                  context,
                  text: greetingForDay(day, lang),
                  reference: formatGregorian(day.gregorian, lang),
                  label: day.name(lang),
                );
              },
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text('xt.rdayShareGreeting'.tr()),
              style: FilledButton.styleFrom(
                  backgroundColor: c.gold, foregroundColor: c.onGold),
            ),
            if (info != null) ...[
              const Gap.md(),
              Text(
                  'xt.rdaySourceDiyanet'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textTertiary)),
            ],
            const Gap.sm(),
          ],
        ),
      ),
    ),
  );
}
