import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/content_providers.dart';
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

/// Kur'an'da arama: meal/kelime/okunuş ile ayet + sure adıyla sure bul.
class QuranSearchScreen extends ConsumerStatefulWidget {
  const QuranSearchScreen({super.key});
  @override
  ConsumerState<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends ConsumerState<QuranSearchScreen> {
  String _query = '';
  static const _cap = 80; // çok uzun listeyi önle

  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    final lang = context.langCode;
    final c = context.colors;
    final surahs = ref.watch(surahsProvider).value ?? const <Surah>[];
    final indexAsync = ref.watch(quranSearchIndexProvider);

    return SelayaScaffold(
      title: tr ? 'Kur\'an\'da Ara' : 'Search the Quran',
      showBack: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base,
              AppSpacing.sm,
              AppSpacing.base,
              AppSpacing.xs,
            ),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: tr
                    ? 'Meal, kelime veya sure adı…'
                    : 'Meaning, word or surah name…',
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
          Expanded(
            child: _query.trim().length < 2
                ? _hint(context, tr)
                : indexAsync.when(
                    loading: () => const SelayaLoading(),
                    error: (e, _) => SelayaError(error: e),
                    data: (index) =>
                        _results(context, tr, lang, surahs, index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _hint(BuildContext context, bool tr) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 56, color: c.textTertiary),
            const Gap.md(),
            Text(
              tr
                  ? 'Ayet meali, bir kelime ya da sure adı yazarak tüm Kur\'an\'da ara.'
                  : 'Type a meaning, a word, or a surah name to search the whole Quran.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(
    BuildContext context,
    bool tr,
    String lang,
    List<Surah> surahs,
    List<(int, Verse)> index,
  ) {
    final c = context.colors;
    final q = _query.trim().toLowerCase();
    final nameOf = {for (final s in surahs) s.number: s.name(lang)};

    // Sure adı eşleşmeleri
    final surahHits = surahs
        .where((s) => s.name(lang).toLowerCase().contains(q))
        .toList();

    // Ayet eşleşmeleri (meal / okunuş)
    final verseHits = <(int, Verse)>[];
    for (final e in index) {
      if (e.$2.meaning(lang).toLowerCase().contains(q) ||
          e.$2.transliteration.toLowerCase().contains(q)) {
        verseHits.add(e);
        if (verseHits.length >= _cap) break;
      }
    }

    if (surahHits.isEmpty && verseHits.isEmpty) {
      return Center(
        child: Text(
          tr ? 'Sonuç bulunamadı' : 'No results',
          style: TextStyle(color: c.textTertiary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        0,
        AppSpacing.base,
        AppSpacing.xxxl,
      ),
      children: [
        if (surahHits.isNotEmpty) ...[
          _sectionTitle(context, tr ? 'Sureler' : 'Surahs', surahHits.length),
          for (final s in surahHits)
            _SurahHit(
              name: s.name(lang),
              number: s.number,
              ayahCount: s.ayahCount,
              onTap: () => context.push('${Routes.quranReader}/${s.number}'),
            ),
          const Gap.md(),
        ],
        if (verseHits.isNotEmpty) ...[
          _sectionTitle(
            context,
            tr ? 'Ayetler' : 'Verses',
            verseHits.length,
            capped: verseHits.length >= _cap,
          ),
          for (final e in verseHits)
            _VerseHit(
              surahName: nameOf[e.$1] ?? 'Sure ${e.$1}',
              ayah: e.$2.ayah,
              meaning: e.$2.meaning(lang),
              onTap: () => context.push('${Routes.quranReader}/${e.$1}'),
            ),
        ],
      ],
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String text,
    int count, {
    bool capped = false,
  }) {
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

class _SurahHit extends StatelessWidget {
  final String name;
  final int number;
  final int ayahCount;
  final VoidCallback onTap;
  const _SurahHit({
    required this.name,
    required this.number,
    required this.ayahCount,
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
              child: Text(
                '$number',
                style: TextStyle(
                  color: c.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const Gap.md(),
            Expanded(
              child: Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$ayahCount',
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
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
  final String meaning;
  final VoidCallback onTap;
  const _VerseHit({
    required this.surahName,
    required this.ayah,
    required this.meaning,
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
            Text(
              '$surahName · $ayah. ayet',
              style: AppTypography.tabular(
                Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: c.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              meaning,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: c.textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
