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

/// Abdest & Taharet Rehberi hub'ı — İslam'daki temizlik (taharet) çeşitleri:
/// Abdest, Gusül, Teyemmüm, Mest üzerine mesh, Yara/sargı üzerine mesh.
/// Her kart tekil görselli/adımlı rehbere (GuideScreen) gider.
class AbdestRehberiScreen extends StatelessWidget {
  const AbdestRehberiScreen({super.key});

  // (guide, panel görsel-koleksiyonu, alt başlık TR, alt başlık EN)
  static const _types = <(Guide, String, String, String)>[
    (abdestGuide, 'guide_abdest', 'Namaz için temizlik — adım adım görselli',
        'Purity for prayer — illustrated steps'),
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
    final c = context.colors;
    final lang = context.langCode;
    return SelayaScaffold(
      title: 'more.abdestGuide'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xxxl),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
                lang == 'tr'
                    ? 'İSLAM\'DA TEMİZLİK (TAHARET) ÇEŞİTLERİ'
                    : 'TYPES OF PURIFICATION (TAHARAH)',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: c.gold,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700)),
          ),
          for (final t in _types) ...[
            _TypeCard(
                guide: t.$1,
                collection: t.$2,
                subtitle: lang == 'tr' ? t.$3 : t.$4,
                lang: lang),
            const Gap.sm(),
          ],
          const Gap.sm(),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.gold.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
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
            ]),
          ),
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
                const SizedBox(height: 2),
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
