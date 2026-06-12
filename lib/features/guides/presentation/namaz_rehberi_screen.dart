import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../domain/prayer_types.dart';

/// Namaz Rehberi hub'ı — üstte adım adım "Namaz nasıl kılınır" rehberi,
/// altında kategorize namaz çeşitleri (5 vakit, vacip & haftalık, nafile, özel).
class NamazRehberiScreen extends StatelessWidget {
  const NamazRehberiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.langCode;
    final cats = lang == 'tr' ? prayerCategoriesTr : prayerCategoriesEn;
    return SelayaScaffold(
      title: 'more.namazGuide'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          // Adım adım görselli rehber (mevcut GuideScreen).
          SelayaCard(
            onTap: () => context.push(Routes.namazHowTo),
            gradient: LinearGradient(colors: c.goldGradient),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: c.bg, size: 26),
                const Gap.base(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          lang == 'tr'
                              ? 'Namaz Nasıl Kılınır?'
                              : 'How to Pray (Step by Step)',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  color: c.bg, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                          lang == 'tr'
                              ? 'Adım adım görselli anlatım'
                              : 'Illustrated step-by-step walkthrough',
                          style: TextStyle(
                              color: c.bg.withValues(alpha: 0.75),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: c.bg),
              ],
            ),
          ),
          const Gap.lg(),
          for (final cat in prayerCategoryOrder) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text((cats[cat] ?? cat).toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: c.gold,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700)),
            ),
            for (final p in prayerTypes.where((p) => p.category == cat)) ...[
              _PrayerTypeCard(p: p, lang: lang),
              const Gap.sm(),
            ],
            const Gap.md(),
          ],
          // Kaynak (#7) — ilk sayfada da belirtilsin.
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.gold.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 16, color: c.gold),
                const Gap.sm(),
                Expanded(
                  child: Text(
                      lang == 'tr'
                          ? 'Kaynak: Diyanet İşleri Başkanlığı İlmihali esas alınmıştır. Ayrıntı için yetkili kaynaklara başvurun.'
                          : 'Source: based on the Diyanet catechism. Consult qualified sources for detail.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textSecondary, height: 1.4)),
                ),
              ],
            ),
          ),
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
              const SizedBox(width: 5),
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
