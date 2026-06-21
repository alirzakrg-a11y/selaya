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
            title: tr ? 'Abdest Nasıl Alınır?' : 'How to Perform Wudu',
            subtitle: tr
                ? 'Adım adım görselli anlatım'
                : 'Illustrated step-by-step walkthrough',
            onTap: () => context.push(Routes.guideDetail,
                extra: (guide: abdestGuide, collection: 'guide_abdest')),
          ),
          const Gap.md(),
          Row(children: [
            Expanded(
                child: GuideQuickLink(
                    icon: Icons.mosque_rounded,
                    label: tr ? 'Namaz' : 'Prayer',
                    onTap: () => context.push(Routes.namazGuide))),
            const Gap.sm(),
            Expanded(
                child: GuideQuickLink(
                    icon: Icons.explore_rounded,
                    label: tr ? 'Kıble' : 'Qibla',
                    onTap: () => context.go(Routes.qibla))),
            const Gap.sm(),
            Expanded(
                child: GuideQuickLink(
                    icon: Icons.schedule_rounded,
                    label: tr ? 'Vakitler' : 'Times',
                    onTap: () => context.go(Routes.times))),
          ]),
          const Gap.lg(),
          GuideSectionLabel(tr ? 'ABDESTİN ESASLARI' : 'WUDU ESSENTIALS'),
          const Gap.sm(),
          GuideExpandCard(
              icon: Icons.checklist_rounded,
              title: tr ? 'Abdestin Farzları' : 'Obligations of Wudu',
              subtitle: tr ? 'Olmazsa olmaz 4 esas' : 'The 4 essentials',
              items: abdestFarzlari,
              lang: lang),
          const Gap.sm(),
          GuideExpandCard(
              icon: Icons.auto_awesome_rounded,
              title: tr ? 'Abdestin Sünnetleri' : 'Sunnahs of Wudu',
              subtitle: tr ? 'Sevabı artıran edepler' : 'Recommended acts',
              items: abdestSunnetleri,
              lang: lang),
          const Gap.sm(),
          GuideExpandCard(
              icon: Icons.report_gmailerrorred_rounded,
              title: tr ? 'Abdesti Bozan Şeyler' : 'What Invalidates Wudu',
              subtitle: tr ? 'Yeniden abdest gerektirir' : 'Require renewing wudu',
              items: abdestiBozanlar,
              lang: lang),
          const Gap.lg(),
          GuideSectionLabel(
              tr ? 'DİĞER TEMİZLİK ÇEŞİTLERİ' : 'OTHER PURIFICATION'),
          const Gap.sm(),
          for (final t in _otherTypes) ...[
            _TypeCard(
                guide: t.$1,
                collection: t.$2,
                subtitle: tr ? t.$3 : t.$4,
                lang: lang),
            const Gap.sm(),
          ],
          const Gap.sm(),
          GuideSourceNote(tr
              ? 'Kaynak: Diyanet İşleri Başkanlığı İlmihali esas alınmıştır. Ayrıntı için yetkili kaynaklara başvurun.'
              : 'Source: based on the Diyanet catechism. Consult qualified sources for detail.'),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final Guide guide;
  final String collection;
  final String subtitle;
  final String lang;
  const _TypeCard(
      {required this.guide,
      required this.collection,
      required this.subtitle,
      required this.lang});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      patterned: true,
      onTap: () => context.push(Routes.guideDetail,
          extra: (guide: guide, collection: collection)),
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
