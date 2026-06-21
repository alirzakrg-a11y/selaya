import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../domain/prayer_basics.dart';
import '../domain/prayer_types.dart';
import 'guide_widgets.dart';

/// Namaz Rehberi hub'ı — adım adım "Namaz nasıl kılınır" + hızlı erişim
/// (abdest/kıble/vakitler) + namazın temelleri (şartları, rükünleri, bozan
/// şeyler, secde-i sehv) + kategorize namaz çeşitleri.
class NamazRehberiScreen extends StatelessWidget {
  const NamazRehberiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final tr = lang == 'tr';
    final cats = tr ? prayerCategoriesTr : prayerCategoriesEn;
    return SelayaScaffold(
      title: 'more.namazGuide'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          GuideHero(
            icon: Icons.menu_book_rounded,
            title: tr ? 'Namaz Nasıl Kılınır?' : 'How to Pray (Step by Step)',
            subtitle: tr
                ? 'Adım adım görselli anlatım'
                : 'Illustrated step-by-step walkthrough',
            onTap: () => context.push(Routes.namazHowTo),
          ),
          const Gap.md(),
          Row(children: [
            Expanded(
                child: GuideQuickLink(
                    icon: Icons.water_drop_rounded,
                    label: tr ? 'Abdest' : 'Wudu',
                    onTap: () => context.push(Routes.abdestGuide))),
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
          GuideSectionLabel(tr ? 'NAMAZIN TEMELLERİ' : 'FUNDAMENTALS'),
          const Gap.sm(),
          GuideExpandCard(
              icon: Icons.checklist_rounded,
              title: tr ? 'Namazın Şartları' : 'Conditions of Prayer',
              subtitle: tr ? 'Namaza başlamadan önce' : 'Before starting',
              items: namazSartlari,
              lang: lang),
          const Gap.sm(),
          GuideExpandCard(
              icon: Icons.account_tree_rounded,
              title: tr ? 'Namazın Rükünleri' : 'Pillars of Prayer',
              subtitle: tr ? 'Namazın içindeki farzlar' : 'Within the prayer',
              items: namazRukunleri,
              lang: lang),
          const Gap.sm(),
          GuideExpandCard(
              icon: Icons.report_gmailerrorred_rounded,
              title: tr ? 'Namazı Bozan Şeyler' : 'What Invalidates Prayer',
              subtitle: tr ? 'Kaçınılması gerekenler' : 'Things to avoid',
              items: namaziBozanlar,
              lang: lang),
          const Gap.sm(),
          GuideExpandCard(
              icon: Icons.healing_rounded,
              title: tr ? 'Secde-i Sehv' : 'Sajdah of Forgetfulness',
              subtitle: tr ? 'Yanılma durumunda' : 'When you err',
              body: tr ? secdeSehvTr : secdeSehvEn,
              lang: lang),
          const Gap.lg(),
          for (final cat in prayerCategoryOrder) ...[
            GuideSectionLabel((cats[cat] ?? cat).toUpperCase()),
            const Gap.sm(),
            for (final p in prayerTypes.where((p) => p.category == cat)) ...[
              _PrayerTypeCard(p: p, lang: lang),
              const Gap.sm(),
            ],
            const Gap.md(),
          ],
          GuideSourceNote(tr
              ? 'Kaynak: Diyanet İşleri Başkanlığı İlmihali esas alınmıştır. Ayrıntı için yetkili kaynaklara başvurun.'
              : 'Source: based on the Diyanet catechism. Consult qualified sources for detail.'),
        ],
      ),
    );
  }
}

class _PrayerTypeCard extends StatelessWidget {
  final PrayerType p;
  final String lang;
  const _PrayerTypeCard({required this.p, required this.lang});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      patterned: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.gold.withValues(alpha: 0.13)),
                child: Icon(p.icon, color: c.gold, size: 18),
              ),
              const Gap.sm(),
              Expanded(
                child: Text(p.name(lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const Gap.sm(),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: c.gold.withValues(alpha: 0.12),
                  borderRadius: AppRadius.rSm,
                  border: Border.all(color: c.gold.withValues(alpha: 0.3))),
              child: Text(p.rakats,
                  style: TextStyle(
                      color: c.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const Gap.sm(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_rounded, size: 13, color: c.textTertiary),
              const Gap.xs(),
              Expanded(
                child: Text(p.whenText(lang),
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ),
            ],
          ),
          const Gap.xs(),
          Text(p.desc(lang),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(height: 1.45, color: c.textSecondary)),
        ],
      ),
    );
  }
}
