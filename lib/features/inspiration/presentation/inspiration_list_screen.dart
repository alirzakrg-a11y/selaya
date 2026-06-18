import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/share/share_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/content_detail_dialog.dart';
import '../../../core/widgets/like_button.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';

/// Tüm ayetleri/hadisleri listeler. Her madde: **beğeni** (kalp + sayı, sunucu),
/// **favori** (yer imi — kalpten AYRI), **paylaş**. `inspirationProvider`'dan tipe
/// göre süzülür: 'verse' = Ayetler, 'hadith' = Hadisler.
class InspirationListScreen extends ConsumerStatefulWidget {
  final String type; // 'verse' | 'hadith'
  final String titleKey;
  final String? openId; // verilirse: liste açılınca o öğenin popup'ı açılır
  const InspirationListScreen(
      {super.key, required this.type, required this.titleKey, this.openId});

  @override
  ConsumerState<InspirationListScreen> createState() =>
      _InspirationListScreenState();
}

class _InspirationListScreenState extends ConsumerState<InspirationListScreen> {
  late Set<String> _favs;
  bool _favsOnly = false;
  bool _autoOpened = false; // openId popup'ı yalnız bir kez aç

  /// Seçili öğenin detay popup'ını aç (◀▶/kaydır + paylaş hazır).
  void _openDetail(
      List<InspirationItem> items, int index, String lang, List wps) {
    showContentDetail(
      context,
      [
        for (final (j, e) in items.indexed)
          ContentDetailItem(
            arabic: e.arabic,
            text: e.text(lang),
            reference: e.reference,
            shareLabel: widget.titleKey.tr(),
            shareBg: wps.isEmpty ? null : wps[j % wps.length].image,
          ),
      ],
      index,
      headerTitle: widget.titleKey.tr(),
    );
  }

  @override
  void initState() {
    super.initState();
    _favs = (ref
                .read(sharedPreferencesProvider)
                .getStringList(PrefKeys.inspirationFavorites) ??
            const [])
        .toSet();
  }

  void _toggleFav(String key) {
    setState(() => _favs.contains(key) ? _favs.remove(key) : _favs.add(key));
    ref
        .read(sharedPreferencesProvider)
        .setStringList(PrefKeys.inspirationFavorites, _favs.toList());
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final c = context.colors;
    final async = ref.watch(inspirationProvider);
    final wps = ref.watch(wallpapersProvider).value ?? const [];

    return SelayaScaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(inspirationProvider),
            child: Text('common.retry'.tr()),
          ),
        ),
        data: (all) {
          final full = all.where((e) => e.type == widget.type).toList();
          var items = full;
          if (_favsOnly) {
            items = items
                .where((e) => _favs.contains('${widget.type}:${e.id}'))
                .toList();
          }
          // openId: ana ekrandaki "Günün Ayeti/Hadisi" kartından gelindiyse o
          // öğenin popup'ını bir kez otomatik aç (tüm listede ara).
          if (!_autoOpened && widget.openId != null) {
            _autoOpened = true;
            final idx = full.indexWhere((e) => e.id == widget.openId);
            if (idx >= 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _openDetail(full, idx, lang, wps);
              });
            }
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: c.bg,
                surfaceTintColor: Colors.transparent,
                title: Text(widget.titleKey.tr()),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.base, 2, AppSpacing.base, 8),
                  child: Row(
                    children: [
                      _Chip(
                          label: 'common.seeAll'.tr(),
                          selected: !_favsOnly,
                          onTap: () => setState(() => _favsOnly = false)),
                      const Gap.sm(),
                      _Chip(
                          label: 'quran.favorites'.tr(),
                          selected: _favsOnly,
                          onTap: () => setState(() => _favsOnly = true)),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('quran.favorites'.tr(),
                        style: TextStyle(color: c.textTertiary)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.base, 0, AppSpacing.base, AppSpacing.xxxl),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final it = items[i];
                      final key = '${widget.type}:${it.id}';
                      final isFav = _favs.contains(key);
                      final bg = wps.isEmpty ? '' : wps[i % wps.length].image;
                      final hasArabic = it.arabic.trim().isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: SelayaCard(
                          patterned: true,
                          // Dokun → ortada büyük popup, ◀▶ oklarla gez, paylaş.
                          onTap: () => _openDetail(items, i, lang, wps),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasArabic) ...[
                                Text(it.arabic,
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                        color: c.goldBright,
                                        fontSize: 19,
                                        height: 1.9)),
                                const Gap.md(),
                              ],
                              Text(it.text(lang),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(height: 1.5)),
                              if (it.reference.isNotEmpty) ...[
                                const Gap.sm(),
                                Text(it.reference,
                                    style: TextStyle(
                                        color: c.gold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ],
                              const Gap.xs(),
                              Divider(
                                  height: 1,
                                  color: c.border.withValues(alpha: 0.4)),
                              Row(
                                children: [
                                  // Beğeni — kalp + sayı (sunucu).
                                  LikeButton(likeKey: key),
                                  const Spacer(),
                                  // Favori — yer imi (kalpten AYRI ikon).
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _toggleFav(key),
                                    icon: Icon(
                                        isFav
                                            ? Icons.bookmark_rounded
                                            : Icons.bookmark_border_rounded,
                                        color: isFav
                                            ? c.gold
                                            : c.textSecondary),
                                  ),
                                  // Paylaş.
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => showVerseShareSheet(
                                      ctx,
                                      arabic: hasArabic ? it.arabic : null,
                                      text: it.text(lang),
                                      reference: it.reference,
                                      label: widget.titleKey.tr(),
                                      backgroundImage: bg,
                                    ),
                                    icon: Icon(Icons.ios_share_rounded,
                                        color: c.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.gold : c.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? c.gold : c.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? const Color(0xFF1A1203) : c.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}
