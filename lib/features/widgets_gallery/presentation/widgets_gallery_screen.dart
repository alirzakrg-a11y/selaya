import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';

/// A small gallery describing the home-screen widgets SELAYA ships, plus how to
/// add them. (The actual widgets are native: Android AppWidget + iOS WidgetKit.)
class WidgetsGalleryScreen extends StatelessWidget {
  const WidgetsGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaScaffold(
      title: 'widgetsGallery.title'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          _WidgetPreview(
            icon: AppIcons.dua,
            title: 'widgetsGallery.hadithTitle'.tr(),
            desc: 'widgetsGallery.hadithDesc'.tr(),
            size: '4×2',
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: AppIcons.kerahat,
            title: 'widgetsGallery.timesTitle'.tr(),
            desc: 'widgetsGallery.timesDesc'.tr(),
            time: '13:02',
            size: '4×2',
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: AppIcons.book,
            title: 'widgetsGallery.ayahTitle'.tr(),
            desc: 'widgetsGallery.ayahDesc'.tr(),
            size: '4×2',
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: AppIcons.mosque,
            title: 'widgetsGallery.esmaTitle'.tr(),
            desc: 'widgetsGallery.esmaDesc'.tr(),
            size: '2×2',
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: AppIcons.calendar,
            title: 'widgetsGallery.hijriTitle'.tr(),
            desc: 'widgetsGallery.hijriDesc'.tr(),
            size: '2×2',
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: Icons.schedule_rounded,
            title: 'widgetsGallery.clockMinimalTitle'.tr(),
            desc: 'widgetsGallery.clockMinimalDesc'.tr(),
            time: '12:48',
            size: '2×2',
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: Icons.access_time_filled_rounded,
            title: 'widgetsGallery.clockGreenTitle'.tr(),
            desc: 'widgetsGallery.clockGreenDesc'.tr(),
            time: '12:48',
            size: '2×2',
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: Icons.mosque_rounded,
            title: 'widgetsGallery.clockPrayerTitle'.tr(),
            desc: 'widgetsGallery.clockPrayerDesc'.tr(),
            time: '12:48',
            size: '4×2',
          ),
          const Gap.lg(),
          SelayaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.info, color: c.gold, size: 20),
                    const Gap.sm(),
                    Text('widgetsGallery.howTo'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const Gap.sm(),
                Text('widgetsGallery.steps'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.textSecondary, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetPreview extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final String? time; // saat/vakit tipi → büyük zaman önizlemesi
  final String size; // "2×2" / "4×2" boyut ipucu
  const _WidgetPreview({
    required this.icon,
    required this.title,
    required this.desc,
    this.time,
    this.size = '2×2',
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      child: Row(
        children: [
          // Mini "ana ekran widget'ı" önizlemesi: saat tipinde büyük zaman,
          // diğerlerinde ikon + içerik iskeleti (faux satırlar).
          Container(
            width: 106,
            height: 80,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: AppRadius.rLg,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.gold.withValues(alpha: 0.28), c.surface],
              ),
              border: Border.all(color: c.gold.withValues(alpha: 0.4)),
            ),
            child: time != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: c.gold, size: 15),
                      const Spacer(),
                      Text(time!,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              height: 1)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: c.gold, size: 22),
                      const Spacer(),
                      Container(
                        height: 6,
                        width: 72,
                        decoration: BoxDecoration(
                            color: c.gold.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 6,
                        width: 48,
                        decoration: BoxDecoration(
                            color: c.border,
                            borderRadius: BorderRadius.circular(3)),
                      ),
                    ],
                  ),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(size,
                          style: TextStyle(
                              color: c.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const Gap.xxs(),
                Text(desc,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
