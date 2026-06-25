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

/// Esmaül Hüsna: 99 İsmin tablosu — her hücre Arapça + okunuş + anlam + ebced
/// gösterir. ARAMA (okunuş/anlam/sıra/Arapça; şapkalı harf duyarsız) + RASTGELE
/// + sayaç. İsme dokun → ortada büyük popup: anlam, ebced, "Zikir Çek" (sayı =
/// ebced) ve paylaş. Ses YOK (spec gereği).
class AsmaScreen extends ConsumerStatefulWidget {
  const AsmaScreen({super.key});
  @override
  ConsumerState<AsmaScreen> createState() => _AsmaScreenState();
}

class _AsmaScreenState extends ConsumerState<AsmaScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Şapkalı/Osmanlıca uzatmaları katlar → "rahman" ⇄ "Rahmân" eşleşir.
  String _fold(String s) => s
      .toLowerCase()
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u')
      .replaceAll('ô', 'o');

  void _open(BuildContext context, List<Asma> items, int index, String lang) {
    showContentDetail(
      context,
      [
        for (final x in items)
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
                '/dhikr?ar=${Uri.encodeComponent(x.arabic)}&name=${Uri.encodeComponent(x.name(lang))}&target=${ebcedValue(x.arabic)}',
              );
            },
          ),
      ],
      index,
      headerTitle: 'asma.title'.tr(),
    );
  }

  void _random(BuildContext context, List<Asma> list, String lang) {
    if (list.isEmpty) return;
    _open(context, list, Random().nextInt(list.length), lang);
  }

  List<Asma> _filter(List<Asma> list, String lang) {
    final q = _fold(_query.trim());
    if (q.isEmpty) return list;
    final raw = _query.trim();
    final num = int.tryParse(raw);
    return list
        .where((a) =>
            _fold(a.transliteration).contains(q) ||
            _fold(a.meaning(lang)).contains(q) ||
            _fold(a.name(lang)).contains(q) ||
            a.arabic.contains(raw) ||
            (num != null && a.order == num))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final c = context.colors;
    final asma = ref.watch(asmaProvider);

    final actions = asma.maybeWhen(
      data: (list) => <Widget>[
        IconButton(
          tooltip: 'xt.asRandom'.tr(),
          onPressed: () => _random(context, list, lang),
          icon: Icon(Icons.shuffle_rounded, color: c.gold),
        ),
      ],
      orElse: () => const <Widget>[],
    );

    return SelayaScaffold(
      title: 'asma.title'.tr(),
      showBack: true,
      actions: actions,
      body: asma.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (list) {
          final filtered = _filter(list, lang);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                    AppSpacing.sm, AppSpacing.base, AppSpacing.xs),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'xt.asSearchHint'.tr(),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 20, color: c.textTertiary),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 19, color: c.textTertiary),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: c.surfaceAlt,
                    border: OutlineInputBorder(
                        borderRadius: AppRadius.rLg,
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.rLg,
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.rLg,
                        borderSide: BorderSide(color: c.gold, width: 1.4)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base + 2, 0, AppSpacing.base, AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _query.trim().isEmpty
                        ? 'asma.subtitle'.tr()
                        : 'xt.asResultsCount'.tr(args: [filtered.length.toString()]),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 40, color: c.textTertiary),
                            const Gap.md(),
                            Text(
                                'xt.asNoResults'.tr(args: [_query.trim()]),
                                style: TextStyle(color: c.textTertiary)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0,
                            AppSpacing.base, AppSpacing.xxxl),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.md,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _AsmaCell(
                          a: filtered[i],
                          lang: lang,
                          onTap: () => _open(context, filtered, i, lang),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bir tablo hücresi: sıra + ebced, büyük Arapça, okunuş, anlam.
class _AsmaCell extends StatelessWidget {
  final Asma a;
  final String lang;
  final VoidCallback onTap;
  const _AsmaCell({required this.a, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final eb = ebcedValue(a.arabic);
    return SelayaCard(
      patterned: true,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: c.gold.withValues(alpha: 0.13),
                child: Text(
                  '${a.order}',
                  style: TextStyle(
                    color: c.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'ebced $eb',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: c.textTertiary),
              ),
            ],
          ),
          const Spacer(),
          Text(
            a.arabic,
            maxLines: 1,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: AppTypography.arabic(fontSize: 30, color: c.gold),
          ),
          const Gap.xs(),
          Text(
            a.transliteration,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            a.meaning(lang),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c.textTertiary, height: 1.3),
          ),
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
