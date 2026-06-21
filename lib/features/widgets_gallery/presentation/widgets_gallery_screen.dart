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
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: AppIcons.kerahat,
            title: 'widgetsGallery.timesTitle'.tr(),
            desc: 'widgetsGallery.timesDesc'.tr(),
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: AppIcons.book,
            title: 'widgetsGallery.ayahTitle'.tr(),
            desc: 'widgetsGallery.ayahDesc'.tr(),
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: AppIcons.mosque,
            title: 'widgetsGallery.esmaTitle'.tr(),
            desc: 'widgetsGallery.esmaDesc'.tr(),
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: AppIcons.calendar,
            title: 'widgetsGallery.hijriTitle'.tr(),
            desc: 'widgetsGallery.hijriDesc'.tr(),
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: Icons.schedule_rounded,
            title: 'widgetsGallery.clockMinimalTitle'.tr(),
            desc: 'widgetsGallery.clockMinimalDesc'.tr(),
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: Icons.access_time_filled_rounded,
            title: 'widgetsGallery.clockGreenTitle'.tr(),
            desc: 'widgetsGallery.clockGreenDesc'.tr(),
          ),
          const Gap.md(),
          _WidgetPreview(
            icon: Icons.mosque_rounded,
            title: 'widgetsGallery.clockPrayerTitle'.tr(),
            desc: 'widgetsGallery.clockPrayerDesc'.tr(),
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
  const _WidgetPreview(
      {required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: AppRadius.rLg,
              gradient: LinearGradient(colors: [
                c.gold.withValues(alpha: 0.25),
                c.surface,
              ]),
              border: Border.all(color: c.gold.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: c.gold, size: 28),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
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
