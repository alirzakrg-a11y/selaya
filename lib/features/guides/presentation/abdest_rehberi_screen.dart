import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../domain/guide.dart';
import '../domain/wudu_basics.dart';
import 'guide_widgets.dart';

/// Abdest & Taharet Rehberi hub'ı — adım adım abdest + hızlı erişim + abdestin
/// esasları (farzları, sünnetleri, bozan şeyler) + diğer temizlik çeşitleri
/// (gusül, teyemmüm, mest/sargı üzerine mesh).
class AbdestRehberiScreen extends StatelessWidget {
  const AbdestRehberiScreen({super.key});

  // Abdest hero olarak ayrıldı; diğer taharet türleri kart olarak listelenir.
  static const _otherTypes = <(Guide, String, String, String)>[
    (gusulGuide, '', 'Boy abdesti — tüm vücudun yıkanması',
        'Full-body ritual washing'),
    (teyemmumGuide, '', 'Su yoksa temiz toprakla abdest',
        'Dry ablution with clean earth'),
    (mestGuide, '', 'Mest giyince ayak yıkamak yerine mesh',
        'Wiping over leather socks'),
    (sargiGuide, '', 'Yara, sargı veya alçı varsa mesh',
        'Wiping over a wound or dressing'),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final tr = lang == 'tr';
    return SelayaScaffold(
      title: 'more.abdestGuide'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          GuideHero(
            icon: Icons.water_drop_rounded,
            title: 'xt.agHeroTitle'.tr(),
            subtitle: 'xt.agHeroSubtitle'.tr(),
            onTap: () =>
                context.push(Routes.guideDetail, extra: abdestGuide),
          ),
          const Gap.md(),
          Row(children: [
            Expanded(
                child: GuideQuickLink(
                    icon: Icons.mosque_rounded,
                    label: 'xt.agLinkPrayer'.tr(),
                    onTap: () => context.push(Routes.namazGuide))),
            const Gap.sm(),
            Expanded(
                child: GuideQuickLink(
                    icon: Icons.explore_rounded,
                    label: 'xt.agLinkQibla'.tr(),
                    onTap: () => context.go(Routes.qibla))),
            const Gap.sm(),
            Expanded(
                child: GuideQuickLink(
                    icon: Icons.schedule_rounded,
                    label: 'xt.agLinkTimes'.tr(),
                    onTap: () => context.go(Routes.times))),
          ]),
          const Gap.lg(),
          GuideSectionLabel('xt.agSectionEssentials'.tr()),
          const Gap.sm(),
          GuideExpandCard(
              icon: Icons.checklist_rounded,
              title: 'xt.agFardTitle'.tr(),
              subtitle: 'xt.agFardSubtitle'.tr(),
              items: abdestFarzlari,
              lang: lang),
          const Gap.sm(),
          GuideExpandCard(
              icon: Icons.auto_awesome_rounded,
              title: 'xt.agSunnahTitle'.tr(),
              subtitle: 'xt.agSunnahSubtitle'.tr(),
              items: abdestSunnetleri,
              lang: lang),
          const Gap.sm(),
          GuideExpandCard(
              icon: Icons.report_gmailerrorred_rounded,
              title: 'xt.agInvalidatorsTitle'.tr(),
              subtitle: 'xt.agInvalidatorsSubtitle'.tr(),
              items: abdestiBozanlar,
              lang: lang),
          const Gap.lg(),
          GuideSectionLabel('xt.agSectionOther'.tr()),
          const Gap.sm(),
          for (final t in _otherTypes) ...[
            _TypeCard(
                guide: t.$1,
                subtitle: tr ? t.$3 : t.$4,
                lang: lang),
            const Gap.sm(),
          ],
          const Gap.sm(),
          GuideSourceNote('xt.agSourceNote'.tr()),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final Guide guide;
  final String subtitle;
  final String lang;
  const _TypeCard(
      {required this.guide, required this.subtitle, required this.lang});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      patterned: true,
      onTap: () => context.push(Routes.guideDetail, extra: guide),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: c.gold.withValues(alpha: 0.13)),
            child: Icon(guide.icon, color: c.gold, size: 22),
          ),
          const Gap.base(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guide.title(lang),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Gap.xxs(),
                Text(subtitle,
                    style: TextStyle(
                        color: c.textSecondary, fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: c.gold, size: 20),
        ],
      ),
    );
  }
}
