import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';

/// Tüm 114 surenin ayetlerini tek listeye indeksler (sure no, Verse). İlk
/// aramada yüklenir (114 dosya) + önbeklenir; sonraki aramalar bellekten.
final quranSearchIndexProvider = FutureProvider<List<(int, Verse)>>((ref) async {
  final lists = await Future.wait([
    for (var n = 1; n <= 114; n++) ref.watch(versesProvider(n).future),
  ]);
  final out = <(int, Verse)>[];
  for (var n = 1; n <= 114; n++) {
    for (final v in lists[n - 1]) {
      out.add((n, v));
    }
  }
  return out;
});

/// Saf arama mantığı (UI'dan bağımsız → test edilebilir): sorguya göre sure +
/// ayet eşleşmelerini döndürür. Sorgu < 2 karakterse boş döner.
class QuranSearchResult {
  final List<Surah> surahs;
  final List<(int, Verse)> verses;
  final bool capped; // ayet sonucu [cap]'e ulaştı (dahası olabilir)
  const QuranSearchResult(this.surahs, this.verses, this.capped);
  bool get isEmpty => surahs.isEmpty && verses.isEmpty;
}

QuranSearchResult quranSearch(
  String query,
  String lang,
  List<Surah> surahs,
  List<(int, Verse)> index, {
  int cap = 60,
}) {
  final q = query.trim().toLowerCase();
  final qRaw = query.trim();
  if (q.length < 2) return const QuranSearchResult([], [], false);
  final surahHits = surahs
      .where((s) =>
          s.name(lang).toLowerCase().contains(q) ||
          s.transliteration.toLowerCase().contains(q))
      .toList();
  final verseHits = <(int, Verse)>[];
  var capped = false;
  for (final e in index) {
    if (e.$2.meaning(lang).toLowerCase().contains(q) ||
        e.$2.transliteration.toLowerCase().contains(q) ||
        e.$2.arabic.contains(qRaw)) {
      verseHits.add(e);
      if (verseHits.length >= cap) {
        capped = true;
        break;
      }
    }
  }
  return QuranSearchResult(surahHits, verseHits, capped);
}

/// Uzun mealde eşleşmeyi görünür tutmak için pencere alır (öncesine "…").
String searchSnippet(String full, String query) {
  final q = query.toLowerCase();
  if (q.isEmpty) return full;
  final mi = full.toLowerCase().indexOf(q);
  if (mi > 72) return '…${full.substring(mi - 52)}';
  return full;
}

/// Kur'an'da arama: meal / kelime / okunuş / Arapça ile ayet + sure adıyla sure
/// bul. Eşleşmeler altın vurgulanır; ayete dokununca okuyucuda tam o ayete
/// atlanır + kısa süre vurgulanır.
class QuranSearchScreen extends ConsumerStatefulWidget {
  const QuranSearchScreen({super.key});
  @override
  ConsumerState<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends ConsumerState<QuranSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  static const _cap = 60; // çok uzun listeyi önle

  static const _suggestTr = [
    'sabır', 'namaz', 'rahmet', 'cennet', 'tövbe', 'şükür', 'rızık', 'hidayet',
  ];
  static const _suggestEn = [
    'patience', 'prayer', 'mercy', 'paradise', 'repentance', 'gratitude',
    'provision', 'guidance',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Her tuşta değil, son tuştan 220ms sonra ara (akıcı + az yeniden çizim).
  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _query = v);
    });
  }

  void _setQuery(String v) {
    _controller.text = v;
    _controller.selection = TextSelection.collapsed(offset: v.length);
    _debounce?.cancel();
    setState(() => _query = v);
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() => _query = '');
  }

  List<String> _recent() =>
      ref.read(sharedPreferencesProvider).getStringList(
            PrefKeys.quranRecentSearches,
          ) ??
      const [];

  void _remember(String q) {
    q = q.trim();
    if (q.length < 2) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final list = <String>[
      q,
      ...(prefs.getStringList(PrefKeys.quranRecentSearches) ?? const [])
          .where((e) => e.toLowerCase() != q.toLowerCase()),
    ];
    prefs.setStringList(
        PrefKeys.quranRecentSearches, list.take(8).toList());
  }

  void _clearRecent() {
    ref.read(sharedPreferencesProvider).remove(PrefKeys.quranRecentSearches);
    setState(() {});
  }

  void _open(int surah, {int? ayah}) {
    _remember(_query);
    final suffix = ayah == null ? '' : '?ayah=$ayah';
    context.push('${Routes.quranReader}/$surah$suffix');
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    final lang = context.langCode;
    final c = context.colors;
    final surahs = ref.watch(surahsProvider).value ?? const <Surah>[];
    final indexAsync = ref.watch(quranSearchIndexProvider);
    final ready = _query.trim().length >= 2;

    return SelayaScaffold(
      title: tr ? 'Kur\'an\'da Ara' : 'Search the Quran',
      showBack: true,
      toolbarHeight: 50,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xs),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: tr
                    ? 'Meal, kelime veya sure adı…'
                    : 'Meaning, word or surah name…',
                prefixIcon:
                    Icon(Icons.search_rounded, color: c.textTertiary, size: 21),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 19, color: c.textTertiary),
                        onPressed: _clear,
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 12),
                filled: true,
                fillColor: c.surfaceAlt,
                border: OutlineInputBorder(
                    borderRadius: AppRadius.rLg, borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.rLg, borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.rLg,
                    borderSide: BorderSide(color: c.gold, width: 1.4)),
              ),
            ),
          ),
          Expanded(
            child: !ready
                ? _emptyState(context, tr)
                : indexAsync.when(
                    loading: () => _loading(context, tr),
                    error: (e, _) => SelayaError(error: e),
                    data: (index) =>
                        _results(context, tr, lang, surahs, index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _loading(BuildContext context, bool tr) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(c.gold)),
          ),
          const Gap.md(),
          Text(tr ? 'Kur\'an taranıyor…' : 'Searching the Quran…',
              style: TextStyle(color: c.textTertiary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, bool tr) {
    final c = context.colors;
    final recent = _recent();
    final suggestions = tr ? _suggestTr : _suggestEn;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.lg, AppSpacing.base, AppSpacing.xxxl),
      children: [
        Icon(Icons.menu_book_rounded,
            size: 50, color: c.gold.withValues(alpha: 0.5)),
        const Gap.md(),
        Text(
          tr
              ? 'Ayet meali, bir kelime ya da sure adı yazarak tüm Kur\'an\'da ara.'
              : 'Type a meaning, a word, or a surah name to search the whole Quran.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, height: 1.5),
        ),
        const Gap.xl(),
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: _label(context, tr ? 'Son aramalar' : 'Recent')),
              GestureDetector(
                onTap: _clearRecent,
                child: Text(tr ? 'Temizle' : 'Clear',
                    style: TextStyle(
                        color: c.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const Gap.sm(),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in recent)
              _chip(context, r, () => _setQuery(r), recent: true),
          ]),
          const Gap.xl(),
        ],
        _label(context, tr ? 'Öneriler' : 'Suggestions'),
        const Gap.sm(),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in suggestions) _chip(context, s, () => _setQuery(s)),
        ]),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.colors.gold,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      );

  Widget _chip(BuildContext context, String label, VoidCallback onTap,
      {bool recent = false}) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(recent ? Icons.history_rounded : Icons.north_east_rounded,
                size: 13, color: c.textTertiary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _results(BuildContext context, bool tr, String lang,
      List<Surah> surahs, List<(int, Verse)> index) {
    final c = context.colors;
    final q = _query.trim().toLowerCase();
    final qRaw = _query.trim();
    final nameOf = {for (final s in surahs) s.number: s.name(lang)};

    final res = quranSearch(_query, lang, surahs, index, cap: _cap);
    final surahHits = res.surahs;
    final verseHits = res.verses;
    final capped = res.capped;

    if (res.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: c.textTertiary),
            const Gap.md(),
            Text(tr ? '"$qRaw" için sonuç yok' : 'No results for "$qRaw"',
                style: TextStyle(color: c.textTertiary)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.xs, AppSpacing.base, AppSpacing.xxxl),
      children: [
        if (surahHits.isNotEmpty) ...[
          _sectionTitle(context, tr ? 'Sureler' : 'Surahs', surahHits.length),
          for (final s in surahHits)
            _SurahHit(
              name: s.name(lang),
              number: s.number,
              ayahCount: s.ayahCount,
              query: q,
              onTap: () => _open(s.number),
            ),
          const Gap.md(),
        ],
        if (verseHits.isNotEmpty) ...[
          _sectionTitle(context, tr ? 'Ayetler' : 'Verses', verseHits.length,
              capped: capped),
          for (final e in verseHits)
            _VerseHit(
              surahName: nameOf[e.$1] ?? 'Sure ${e.$1}',
              ayah: e.$2.ayah,
              arabic: e.$2.arabic,
              meaning: e.$2.meaning(lang),
              query: q,
              tr: tr,
              onTap: () => _open(e.$1, ayah: e.$2.ayah),
            ),
        ],
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text, int count,
      {bool capped = false}) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 6),
      child: Text(
        capped ? '$text · $count+' : '$text · $count',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: c.gold,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

/// Eşleşen kısmı altın vurgulayan metin. Uzun mealde eşleşme etrafından bir
/// pencere alır (öncesine "…") → eşleşme her zaman görünür kalır.
Widget _highlighted(
  BuildContext context,
  String full,
  String query,
  TextStyle base, {
  int maxLines = 3,
}) {
  final c = context.colors;
  final q = query.toLowerCase();
  final text = searchSnippet(full, query);
  final lower = text.toLowerCase();
  if (q.isEmpty || !lower.contains(q)) {
    return Text(text,
        maxLines: maxLines, overflow: TextOverflow.ellipsis, style: base);
  }
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final i = lower.indexOf(q, start);
    if (i < 0) {
      spans.add(TextSpan(text: text.substring(start)));
      break;
    }
    if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
    spans.add(TextSpan(
      text: text.substring(i, i + q.length),
      style: TextStyle(color: c.gold, fontWeight: FontWeight.w800),
    ));
    start = i + q.length;
  }
  return Text.rich(TextSpan(style: base, children: spans),
      maxLines: maxLines, overflow: TextOverflow.ellipsis);
}

class _SurahHit extends StatelessWidget {
  final String name;
  final int number;
  final int ayahCount;
  final String query;
  final VoidCallback onTap;
  const _SurahHit({
    required this.name,
    required this.number,
    required this.ayahCount,
    required this.query,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SelayaCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: c.gold.withValues(alpha: 0.14),
              child: Text('$number',
                  style: TextStyle(
                      color: c.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ),
            const Gap.md(),
            Expanded(
              child: _highlighted(
                context,
                name,
                query,
                Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
              ),
            ),
            Text('$ayahCount',
                style: TextStyle(color: c.textTertiary, fontSize: 12)),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _VerseHit extends StatelessWidget {
  final String surahName;
  final int ayah;
  final String arabic;
  final String meaning;
  final String query;
  final bool tr;
  final VoidCallback onTap;
  const _VerseHit({
    required this.surahName,
    required this.ayah,
    required this.arabic,
    required this.meaning,
    required this.query,
    required this.tr,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SelayaCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$surahName · $ayah. ${tr ? 'ayet' : 'ayah'}',
                    style: AppTypography.tabular(
                      Theme.of(context).textTheme.labelMedium!.copyWith(
                            color: c.gold,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    size: 15, color: c.gold.withValues(alpha: 0.7)),
              ],
            ),
            if (arabic.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                arabic,
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.arabic(fontSize: 19, color: c.textPrimary),
              ),
            ],
            const SizedBox(height: 5),
            _highlighted(
              context,
              meaning,
              query,
              Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: c.textSecondary, height: 1.45),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
