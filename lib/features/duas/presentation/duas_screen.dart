import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/share/share_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/content_detail_dialog.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';

class DuasScreen extends ConsumerStatefulWidget {
  const DuasScreen({super.key});
  @override
  ConsumerState<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends ConsumerState<DuasScreen> {
  String _category = 'all';
  String _query = '';
  late Set<String> _favs;

  static const _categories = [
    'all',
    'morning',
    'evening',
    'prayer',
    'daily',
    'protection',
  ];

  @override
  void initState() {
    super.initState();
    _favs =
        (ref
                    .read(sharedPreferencesProvider)
                    .getStringList(PrefKeys.duaFavorites) ??
                const [])
            .toSet();
  }

  void _toggleFav(String id) {
    setState(() {
      _favs.contains(id) ? _favs.remove(id) : _favs.add(id);
    });
    ref
        .read(sharedPreferencesProvider)
        .setStringList(PrefKeys.duaFavorites, _favs.toList());
  }

  String _label(String cat) =>
      cat == 'all' ? 'common.seeAll'.tr() : 'duas.$cat'.tr();

  static IconData _catIcon(String cat) => switch (cat) {
    'morning' => Icons.wb_twilight_rounded,
    'evening' => Icons.nightlight_round,
    'prayer' => Icons.mosque_rounded,
    'daily' => Icons.event_repeat_rounded,
    'protection' => Icons.shield_moon_rounded,
    _ => Icons.apps_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final c = context.colors;
    final duas = ref.watch(duasProvider);

    return SelayaScaffold(
      title: 'duas.title'.tr(),
      showBack: true,
      body: duas.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (all) => DefaultTabController(
          length: 2,
          child: Column(
            children: [
              _header(c, all.length),
              TabBar(
                labelColor: c.gold,
                unselectedLabelColor: c.textTertiary,
                indicatorColor: c.gold,
                tabs: [
                  Tab(text: 'duas.tabList'.tr()),
                  Tab(text: 'duas.tabFavorites'.tr()),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [_listTab(all, lang), _favTab(all, lang)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listTab(List<Dua> all, String lang) {
    final c = context.colors;
    final q = _query.trim().toLowerCase();
    var list = _category == 'all'
        ? all
        : all.where((d) => d.category == _category).toList();
    if (q.isNotEmpty) {
      list = list
          .where(
            (d) =>
                d.title(lang).toLowerCase().contains(q) ||
                d.text(lang).toLowerCase().contains(q) ||
                d.transliteration.toLowerCase().contains(q),
          )
          .toList();
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.xs,
            AppSpacing.base,
            AppSpacing.xs,
          ),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'duas.searchHint'.tr(),
              prefixIcon: Icon(Icons.search_rounded, color: c.textTertiary),
              isDense: true,
              filled: true,
              fillColor: c.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: AppRadius.rLg,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // Kategoriler üstten ÇİP yerine KART-TABLO (kullanıcı 2026-06-17): 3
        // sütunlu kart grid; seçili kart altın çerçeveyle ayrışır, alttaki liste
        // ona göre filtrelenir. FittedBox sayesinde büyük fontta da taşmaz.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.xs,
            AppSpacing.base,
            0,
          ),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.55,
            children: [
              for (final cat in _categories)
                _CatCard(
                  label: _label(cat),
                  icon: _catIcon(cat),
                  selected: cat == _category,
                  onTap: () => setState(() => _category = cat),
                ),
            ],
          ),
        ),
        const Gap.sm(),
        Expanded(
          child: list.isEmpty
              ? const SelayaEmpty()
              : _DuaList(
                  duas: list,
                  lang: lang,
                  favs: _favs,
                  onFav: _toggleFav,
                ),
        ),
      ],
    );
  }

  Widget _favTab(List<Dua> all, String lang) {
    final favs = all.where((d) => _favs.contains(d.id)).toList();
    return favs.isEmpty
        ? SelayaEmpty(message: 'duas.noFavorites'.tr())
        : _DuaList(duas: favs, lang: lang, favs: _favs, onFav: _toggleFav);
  }

  /// Gold-gradient visual header (like the Quran tab's), with a count subtitle.
  Widget _header(SelayaColors c, int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.gold.withValues(alpha: 0.22), c.surfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.rXl,
        border: Border.all(color: c.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.gold.withValues(alpha: 0.16),
            ),
            child: Icon(
              Icons.volunteer_activism_rounded,
              color: c.gold,
              size: 24,
            ),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'duas.title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'duas.headerSubtitle'.tr(args: ['$count']),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dua kategorisi kartı — üstten çip yerine kart-tablo (kullanıcı 2026-06-17).
class _CatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _CatCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rMd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.gold.withValues(alpha: 0.16) : c.surfaceAlt,
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: selected ? c.gold : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: selected ? c.gold : c.textSecondary),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? c.gold : c.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuaList extends StatelessWidget {
  final List<Dua> duas;
  final String lang;
  final Set<String> favs;
  final void Function(String) onFav;
  const _DuaList({
    required this.duas,
    required this.lang,
    required this.favs,
    required this.onFav,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.xxxl,
      ),
      itemCount: duas.length,
      separatorBuilder: (_, _) => const Gap.md(),
      itemBuilder: (context, i) => _DuaCard(
        dua: duas[i],
        allDuas: duas,
        index: i,
        lang: lang,
        fav: favs.contains(duas[i].id),
        onFav: () => onFav(duas[i].id),
      ),
    );
  }
}

class _DuaCard extends StatelessWidget {
  final Dua dua;
  final List<Dua> allDuas;
  final int index;
  final String lang;
  final bool fav;
  final VoidCallback onFav;
  const _DuaCard({
    required this.dua,
    required this.allDuas,
    required this.index,
    required this.lang,
    required this.fav,
    required this.onFav,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      patterned: true,
      // Dokununca popup açılır — oklarla gezilir + paylaş (namaz rehberi gibi).
      onTap: () => showDuaDetail(context, allDuas, index, lang),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dua.title(lang),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: c.gold),
                ),
              ),
              // ⑭ Paylaş — duayı doğrudan paylaş (kart üzerinden).
              InkWell(
                onTap: () => showVerseShareSheet(
                  context,
                  arabic: dua.arabic.isEmpty ? null : dua.arabic,
                  text: dua.text(lang),
                  reference: dua.source,
                  label: dua.title(lang),
                ),
                borderRadius: BorderRadius.circular(99),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.ios_share_rounded,
                    size: 18,
                    color: c.textSecondary,
                  ),
                ),
              ),
              InkWell(
                onTap: onFav,
                borderRadius: BorderRadius.circular(99),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    fav ? AppIcons.favoriteFilled : AppIcons.favorite,
                    size: 20,
                    color: fav ? c.danger : c.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const Gap.md(),
          // Tam genişlik şart: yoksa kısa Arapça (start-hizalı Column'da) içeriğe
          // göre büzülüp SOLDA görünür → RTL sağa yaslama görünmez kalır.
          SizedBox(
            width: double.infinity,
            child: Text(
              dua.arabic,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: AppTypography.arabic(fontSize: 26, color: c.textPrimary),
            ),
          ),
          if (dua.transliteration.isNotEmpty) ...[
            const Gap.sm(),
            Text(
              dua.transliteration,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.gold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const Gap.sm(),
          Text(
            dua.text(lang),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
          if (dua.source.isNotEmpty) ...[
            const Gap.sm(),
            Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 14, color: c.gold),
                const SizedBox(width: 5),
                Text(
                  '${lang == 'tr' ? 'Kaynak' : 'Source'}: ${dua.source}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: c.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Bir duâya dokununca açılan popup — namaz rehberi gibi büyük görünüm,
/// oklarla (◀ ▶) veya kaydırarak duâlar arası geçiş + paylaş.
void showDuaDetail(
  BuildContext context,
  List<Dua> duas,
  int index,
  String lang,
) {
  // ⑦ Genel ADAPTİF popup'a taşındı: yükseklik içeriğe göre (kısa dua = küçük
  // popup; eskiden _DuaDetailDialog hep %82 doluyordu). ◀▶/kaydır + paylaş hazır.
  showContentDetail(
    context,
    [
      for (final d in duas)
        ContentDetailItem(
          title: d.title(lang),
          arabic: d.arabic,
          transliteration: d.transliteration,
          text: d.text(lang),
          reference: d.source,
          shareLabel: d.title(lang),
        ),
    ],
    index,
    headerTitle: lang == 'tr' ? 'Dualar' : 'Duas',
  );
}

class _DuaDetailDialog extends StatefulWidget {
  final List<Dua> duas;
  final int initial;
  final String lang;
  const _DuaDetailDialog({
    required this.duas,
    required this.initial,
    required this.lang,
  });
  @override
  State<_DuaDetailDialog> createState() => _DuaDetailDialogState();
}

class _DuaDetailDialogState extends State<_DuaDetailDialog> {
  late final PageController _pc = PageController(initialPage: widget.initial);
  late int _i = widget.initial;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final n = _i + delta;
    if (n < 0 || n >= widget.duas.length) return;
    _pc.animateToPage(
      n,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = widget.lang;
    final total = widget.duas.length;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xl,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppRadius.rXl,
          border: Border.all(color: c.gold.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.rXl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık şeridi + kapat
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.gold.withValues(alpha: 0.18), c.surfaceAlt],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.volunteer_activism_rounded,
                      color: c.gold,
                      size: 20,
                    ),
                    const Gap.sm(),
                    Expanded(
                      child: Text(
                        'duas.title'.tr(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: c.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: c.textSecondary),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: PageView.builder(
                  controller: _pc,
                  onPageChanged: (p) => setState(() => _i = p),
                  itemCount: total,
                  itemBuilder: (_, idx) {
                    final d = widget.duas[idx];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            d.title(lang),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (d.arabic.isNotEmpty) ...[
                            const Gap.lg(),
                            Text(
                              d.arabic,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: AppTypography.arabic(
                                fontSize: 30,
                                color: c.textPrimary,
                                height: 1.95,
                              ),
                            ),
                          ],
                          if (d.transliteration.isNotEmpty) ...[
                            const Gap.md(),
                            Text(
                              d.transliteration,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: c.gold,
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                  ),
                            ),
                          ],
                          const Gap.md(),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: AppRadius.rLg,
                            ),
                            child: Text(
                              '"${d.text(lang)}"',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: c.textSecondary,
                                    height: 1.6,
                                  ),
                            ),
                          ),
                          if (d.source.isNotEmpty) ...[
                            const Gap.md(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 14,
                                  color: c.gold,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '${lang == 'tr' ? 'Kaynak' : 'Source'}: ${d.source}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: c.textTertiary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Alt çubuk: ◀  sayaç + paylaş  ▶
              Container(
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _i > 0 ? () => _go(-1) : null,
                      icon: const Icon(Icons.chevron_left_rounded, size: 30),
                      color: c.gold,
                      disabledColor: c.textTertiary.withValues(alpha: 0.4),
                    ),
                    Expanded(
                      child: Text(
                        '${_i + 1} / $total',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final d = widget.duas[_i];
                        showVerseShareSheet(
                          context,
                          arabic: d.arabic.isEmpty ? null : d.arabic,
                          text: d.text(lang),
                          reference: d.source,
                          label: d.title(lang),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 22),
                      color: c.gold,
                      tooltip: 'common.share'.tr(),
                    ),
                    IconButton(
                      onPressed: _i < total - 1 ? () => _go(1) : null,
                      icon: const Icon(Icons.chevron_right_rounded, size: 30),
                      color: c.gold,
                      disabledColor: c.textTertiary.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
