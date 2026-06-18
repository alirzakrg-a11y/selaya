import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../data/quran_favorites.dart';

const _juzStart = [1, 2, 2, 3, 4, 4, 5, 6, 7, 8, 9, 11, 12, 15, 17, 18, 21, 23,
    25, 27, 29, 33, 36, 39, 41, 46, 51, 58, 67, 78];

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});
  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> {
  String _query = '';

  int? get _lastRead =>
      ref.read(sharedPreferencesProvider).getInt(PrefKeys.quranLastRead);

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final surahs = ref.watch(surahsProvider);
    // ② Favori = now-playing ile AYNI provider (ekran kendi yerel _favs'ını
    // tutuyordu → player'la senkronsuzdu; artık tek kaynak).
    final favs = ref.watch(quranFavoritesProvider);
    final c = context.colors;

    return DefaultTabController(
      length: 3,
      child: SelayaScaffold(
        title: 'quran.title'.tr(),
        showBack: Navigator.of(context).canPop(),
        body: surahs.when(
          loading: () => const SelayaLoading(),
          error: (e, _) => SelayaError(error: e),
          data: (all) {
            final q = _query.toLowerCase();
            final filtered = _query.isEmpty
                ? all
                : all
                    .where((s) =>
                        s.name(lang).toLowerCase().contains(q) ||
                        s.transliteration.toLowerCase().contains(q) ||
                        s.number.toString() == _query)
                    .toList();
            final favSurahs =
                all.where((s) => favs.contains(s.number)).toList();
            final last = _lastRead;
            final lastSurah = last == null
                ? null
                : all.firstWhere((s) => s.number == last,
                    orElse: () => all.first);

            return Column(
              children: [
                Padding(
                  // İnce arama kutusu — üst blok ferah ama küçük kalsın.
                  padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                      AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'quran.searchHint'.tr(),
                      prefixIcon: const Icon(AppIcons.search, size: 19),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      filled: true,
                      fillColor: c.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.rLg,
                        borderSide: BorderSide(color: c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.rLg,
                        borderSide: BorderSide(color: c.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.rLg,
                        borderSide: BorderSide(color: c.gold, width: 1.4),
                      ),
                    ),
                  ),
                ),
                // Kaldığın yerden devam: son okunan · dinle · mushaf → tek satır
                // kompakt mini kartlar (eskiden 2 kart + tam genişlik mushaf kartı
                // 3 ayrı blok yer kaplıyordu; artık tek küçük satır).
                if (_query.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MiniAction(
                            icon: AppIcons.book,
                            label: 'quran.lastRead'.tr(),
                            value: lastSurah?.name(lang) ?? '—',
                            onTap: () => context.push(
                                '${Routes.quranReader}/${lastSurah?.number ?? 1}'),
                          ),
                        ),
                        const Gap.sm(),
                        Expanded(
                          child: _MiniAction(
                            icon: AppIcons.playCircle,
                            label: lang == 'tr' ? 'Dinle' : 'Listen',
                            value: (lastSurah ?? all.first).name(lang),
                            accent: true,
                            onTap: () => context.push(
                                '${Routes.quranReader}/${lastSurah?.number ?? 1}'),
                          ),
                        ),
                        const Gap.sm(),
                        Expanded(
                          child: _MiniAction(
                            icon: Icons.auto_stories_rounded,
                            label: 'Mushaf',
                            value: lang == 'tr'
                                ? 'Sayfa ${ref.read(sharedPreferencesProvider).getInt(PrefKeys.mushafLastPage) ?? 1}'
                                : 'Page ${ref.read(sharedPreferencesProvider).getInt(PrefKeys.mushafLastPage) ?? 1}',
                            onTap: () => context.push(Routes.mushaf),
                          ),
                        ),
                      ],
                    ),
                  ),
                TabBar(
                  labelColor: c.gold,
                  unselectedLabelColor: c.textTertiary,
                  indicatorColor: c.gold,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
                    Tab(text: 'quran.surahs'.tr()),
                    Tab(text: 'quran.juz'.tr()),
                    Tab(text: 'quran.favorites'.tr()),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _SurahList(
                          surahs: filtered,
                          favs: favs,
                          onFav: (n) => ref
                              .read(quranFavoritesProvider.notifier)
                              .toggle(n)),
                      _JuzList(all: all),
                      favSurahs.isEmpty
                          ? SelayaEmpty(message: 'quran.noFavorites'.tr())
                          : _SurahList(
                              surahs: favSurahs,
                              favs: favs,
                              onFav: (n) => ref
                                  .read(quranFavoritesProvider.notifier)
                                  .toggle(n)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Kompakt "kaldığın yerden devam" mini kartı — üstte küçük altın ikon rozeti,
/// altında etiket + değer (tek satır). Üçü yan yana tek satırda durur.
class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool accent;
  final VoidCallback onTap;
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: onTap,
      borderRadius: AppRadius.rLg,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.md),
      gradient: accent
          ? LinearGradient(
              colors: [c.gold.withValues(alpha: 0.20), c.surfaceAlt],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: accent ? 0.24 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c.gold, size: 18),
          ),
          const Gap.xs(),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.textTertiary, fontSize: 10.5)),
          const SizedBox(height: 1),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  final List<Surah> surahs;
  final Set<int> favs;
  final void Function(int) onFav;
  const _SurahList(
      {required this.surahs, required this.favs, required this.onFav});

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    if (surahs.isEmpty) return const SelayaEmpty();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xxxl),
      itemCount: surahs.length,
      separatorBuilder: (_, _) => const Gap.sm(),
      itemBuilder: (context, i) => _SurahTile(
        surah: surahs[i],
        lang: lang,
        fav: favs.contains(surahs[i].number),
        onFav: () => onFav(surahs[i].number),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final Surah surah;
  final String lang;
  final bool fav;
  final VoidCallback onFav;
  const _SurahTile(
      {required this.surah,
      required this.lang,
      required this.fav,
      required this.onFav});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: () => context.push('${Routes.quranReader}/${surah.number}'),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: 0.785,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Text('${surah.number}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: c.gold, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(surah.name(lang),
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${surah.revelation == 'meccan' ? 'quran.meccan'.tr() : 'quran.medinan'.tr()} • ${'quran.ayahCount'.tr(args: [
                        surah.ayahCount.toString()
                      ])}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textTertiary),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onFav,
            borderRadius: BorderRadius.circular(99),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(fav ? AppIcons.favoriteFilled : AppIcons.favorite,
                  size: 18, color: fav ? c.danger : c.textTertiary),
            ),
          ),
          const Gap.xs(),
          Text(surah.arabic,
              textDirection: TextDirection.rtl,
              style: AppTypography.arabic(fontSize: 22, color: c.gold)),
        ],
      ),
    );
  }
}

class _JuzList extends StatelessWidget {
  final List<Surah> all;
  const _JuzList({required this.all});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.langCode;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xxxl),
      itemCount: 30,
      separatorBuilder: (_, _) => const Gap.sm(),
      itemBuilder: (context, i) {
        final juz = i + 1;
        final startSurah = all.firstWhere((s) => s.number == _juzStart[i],
            orElse: () => all.first);
        return SelayaCard(
          onTap: () =>
              context.push('${Routes.quranReader}/${startSurah.number}'),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: c.gold.withValues(alpha: 0.12),
                child: Text('$juz',
                    style: TextStyle(color: c.gold, fontWeight: FontWeight.w700)),
              ),
              const Gap.md(),
              Expanded(
                child: Text('${'quran.juz'.tr()} $juz',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(startSurah.name(lang),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textTertiary)),
              const Gap.sm(),
              const Icon(AppIcons.forward, size: 18),
            ],
          ),
        );
      },
    );
  }
}
