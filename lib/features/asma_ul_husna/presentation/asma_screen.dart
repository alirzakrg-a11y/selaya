import 'dart:math';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/utils/ebced.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_detail_dialog.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';

/// Esmaül Hüsna (#10): a tablo/matrix of the 99 Names — each cell shows the
/// Arabic, its transliteration, meaning and ebced value. NO audio (removed per
/// spec). Tapping a name opens a detail sheet with meaning, ebced, a zikir
/// suggestion, a "Zikir Çek" launcher (count = ebced) and share.
class AsmaScreen extends ConsumerWidget {
  const AsmaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final c = context.colors;
    final asma = ref.watch(asmaProvider);

    return SelayaScaffold(
      title: 'asma.title'.tr(),
      showBack: true,
      body: asma.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (list) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
              child: Text('asma.subtitle'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.textSecondary)),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0,
                    AppSpacing.base, AppSpacing.xxxl),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.82,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) =>
                    _AsmaCell(a: list[i], list: list, index: i, lang: lang),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One matrix cell: order + ebced, big Arabic, transliteration, meaning.
class _AsmaCell extends StatelessWidget {
  final Asma a;
  final List<Asma> list;
  final int index;
  final String lang;
  const _AsmaCell(
      {required this.a,
      required this.list,
      required this.index,
      required this.lang});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final eb = ebcedValue(a.arabic);
    return SelayaCard(
      patterned: true,
      // Dokun → ortada büyük popup, ◀▶ oklarla 99 isim arası gez, Zikir Çek + paylaş.
      onTap: () => showContentDetail(
        context,
        [
          for (final x in list)
            ContentDetailItem(
              title: x.name(lang),
              arabic: x.arabic,
              transliteration: x.transliteration,
              text: x.meaning(lang),
              reference: 'ebced ${ebcedValue(x.arabic)}',
              shareLabel: 'asma.title'.tr(),
              shareBg: _bgFallback[Random().nextInt(_bgFallback.length)],
              actionLabel: 'asma.doZikir'.tr(),
              actionIcon: Icons.repeat_rounded,
              onAction: (ctx) {
                Navigator.of(ctx).pop();
                ctx.push(
                    '/dhikr?ar=${Uri.encodeComponent(x.arabic)}&name=${Uri.encodeComponent(x.name(lang))}&target=${ebcedValue(x.arabic)}');
              },
            ),
        ],
        index,
        headerTitle: 'asma.title'.tr(),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: c.gold.withValues(alpha: 0.13),
                child: Text('${a.order}',
                    style: TextStyle(
                        color: c.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
              const Spacer(),
              Text('ebced $eb',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: c.textTertiary)),
            ],
          ),
          const Spacer(),
          Text(a.arabic,
              maxLines: 1,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: AppTypography.arabic(fontSize: 30, color: c.gold)),
          const Gap.xs(),
          Text(a.transliteration,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(a.meaning(lang),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textTertiary, height: 1.3)),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Esma paylaşım kartının arka planı için paket-içi yedek duvar kâğıtları —
/// `wallpapersProvider` (panel/CDN) boş olsa bile her zaman bir arka plan olsun.
const _bgFallback = [
  'assets/images/wallpapers/wp_kaaba_1.jpg',
  'assets/images/wallpapers/wp_nabawi_1.jpg',
  'assets/images/wallpapers/wp_mosque_1.jpg',
  'assets/images/wallpapers/wp_night_1.jpg',
  'assets/images/wallpapers/wp_calligraphy_1.jpg',
  'assets/images/wallpapers/wp_ramadan_1.jpg',
  'assets/images/wallpapers/wp_kaaba_2.jpg',
  'assets/images/wallpapers/wp_mosque_2.jpg',
  'assets/images/wallpapers/wp_nabawi_2.jpg',
  'assets/images/wallpapers/wp_night_2.jpg',
];

