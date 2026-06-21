import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/mosque_adab.dart';

/// Cami/mescit adabı + giriş-çıkış duaları sayfası (AppBar bilgi butonundan).
void showMosqueGuideSheet(BuildContext context) {
  final c = context.colors;
  final lang = context.langCode;
  final tr = lang == 'tr';

  Widget label(String t) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(t,
            style: TextStyle(
                color: c.gold,
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w700)),
      );

  Widget duaCard(String title, MosqueDua d) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.gold.withValues(alpha: 0.08),
          borderRadius: AppRadius.rLg,
          border: Border.all(color: c.gold.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const Gap.sm(),
            Text(d.arabic,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: AppTypography.arabic(fontSize: 22, color: c.textPrimary)),
            const Gap.sm(),
            Text(d.reading,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.gold, fontStyle: FontStyle.italic, height: 1.4)),
            const Gap.xs(),
            Text(d.meaning(lang),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.textSecondary, height: 1.45)),
            const Gap.xs(),
            Text(d.source,
                style: TextStyle(
                    color: c.gold, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.95,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Icon(Icons.mosque_rounded, color: c.gold),
                const Gap.sm(),
                Expanded(
                  child: Text(
                      tr ? 'Cami Adabı & Duaları' : 'Mosque Etiquette & Du‘as',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const Gap.lg(),
            label(tr ? 'GİRİŞ & ÇIKIŞ DUALARI' : 'ENTRY & EXIT DU‘AS'),
            duaCard(tr ? 'Mescide girerken' : 'When entering', mosqueEnterDua),
            duaCard(tr ? 'Mescidden çıkarken' : 'When leaving', mosqueExitDua),
            const Gap.lg(),
            label(tr ? 'CAMİ ADABI' : 'MOSQUE ETIQUETTE'),
            for (var i = 0; i < mosqueAdab.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.gold.withValues(alpha: 0.14)),
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: c.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                    const Gap.md(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mosqueAdab[i].title(lang),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const Gap.xxs(),
                          Text(mosqueAdab[i].desc(lang),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: c.textSecondary, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Gap.xs(),
            Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 16, color: c.gold),
                const Gap.sm(),
                Expanded(
                  child: Text(
                      tr
                          ? 'Kaynak: Diyanet İşleri Başkanlığı çizgisinde hazırlanmıştır.'
                          : 'Based on the Diyanet (Presidency of Religious Affairs).',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textTertiary)),
                ),
              ],
            ),
            const Gap.sm(),
          ],
        ),
      ),
    ),
  );
}
