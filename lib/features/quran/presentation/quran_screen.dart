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
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../data/quran_audio_controller.dart';
import '../data/quran_download_service.dart';
import '../data/quran_favorites.dart';
import '../data/quran_tracks.dart';

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

  /// 🎧 "Dinlemeye Başla": okuyucuya GİTMEDEN sureyi doğrudan çalar — kullanıcı
  /// listede kalır, kumanda global mini'de belirir (alt menü kapanmaz). Sesli
  /// ayet verisi yoksa/yüklenemezse eski davranışa düşer: okuyucu açılır.
  Future<void> _startListening(Surah s) async {
    final lang = context.langCode;
    try {
      final verses = await ref.read(versesProvider(s.number).future);
      final tracks = buildQuranTracks(
          s.number, s.name(lang), verses, quranWallpaperArt(ref, s.number));
      if (tracks.isEmpty) {
        if (mounted) context.go('${Routes.quranReader}/${s.number}');
        return;
      }
      await ref
          .read(quranAudioControllerProvider.notifier)
          .play(s.number, s.name(lang), tracks, 0);
      // Çalmayı LİSTEDE değil OKUYUCUDA yönet: liste artık indirme-only, üstünde
      // dur/duraklat kumandası yok. Çalar çalmaz okuyucuya geç → alt bardan
      // (play/pause + ◀▶) kontrol edilir.
      if (mounted) context.go('${Routes.quranReader}/${s.number}');
    } catch (_) {
      if (mounted) context.go('${Routes.quranReader}/${s.number}');
    }
  }

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
                  // Breathing room below the title and a clear gap before the
                  // cards/tabs (the search box was glued to them otherwise).
                  padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                      AppSpacing.sm, AppSpacing.base, AppSpacing.md),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'quran.searchHint'.tr(),
                      prefixIcon: const Icon(AppIcons.search, size: 20),
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
                    ),
                  ),
                ),
                // Last-read + start-listening cards.
                if (_query.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.base, 0, AppSpacing.base, AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TopCard(
                            icon: AppIcons.book,
                            label: 'quran.lastRead'.tr(),
                            value: lastSurah?.name(lang) ?? '—',
                            onTap: () => context.go(
                                '${Routes.quranReader}/${lastSurah?.number ?? 1}'),
                          ),
                        ),
                        const Gap.sm(),
                        Expanded(
                          child: _TopCard(
                            icon: AppIcons.playCircle,
                            label: 'quran.startListening'.tr(),
                            value: (lastSurah ?? all.first).name(lang),
                            accent: true,
                            onTap: () =>
                                _startListening(lastSurah ?? all.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                // 📖 Mushaf Modu — sayfa sayfa gerçek mushaf (kaldığı yerden).
                if (_query.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.base, 0, AppSpacing.base, AppSpacing.md),
                    child: _TopCard(
                      icon: Icons.auto_stories_rounded,
                      label: lang == 'tr' ? 'Mushaf Modu' : 'Mushaf View',
                      value: lang == 'tr'
                          ? 'Sayfa ${ref.read(sharedPreferencesProvider).getInt(PrefKeys.mushafLastPage) ?? 1} — sayfa sayfa oku'
                          : 'Page ${ref.read(sharedPreferencesProvider).getInt(PrefKeys.mushafLastPage) ?? 1} — read page by page',
                      onTap: () => context.go(Routes.mushaf),
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

class _TopCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool accent;
  final VoidCallback onTap;
  const _TopCard({
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
      padding: const EdgeInsets.all(AppSpacing.md),
      gradient: accent
          ? LinearGradient(colors: [c.gold.withValues(alpha: 0.18), c.surfaceAlt])
          : null,
      child: Row(
        children: [
          Icon(icon, color: c.gold, size: 22),
          const Gap.sm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: c.textTertiary)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
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
      onTap: () => context.go('${Routes.quranReader}/${surah.number}'),
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
          const Gap.sm(),
          // ⬇ OFFLINE indirme (liste = indirme; çalma okuyucuda). İndirilince ✓.
          _DownloadButton(surah: surah, lang: lang),
        ],
      ),
    );
  }
}

/// Sure satırındaki TEK buton: ⬇ (offline indir) → indirilirken % + dolan halka
/// → ✓ (indirildi). Liste ekranında ÇALMA YOK (kullanıcı 2026-06-14: "bu
/// sayfalardan play'i kaldır, girince sadece play olsun") — çalma yalnız
/// okuyucuda. İndirme ONAY ister (kullanıcı yanlışlıkla basıp veri harcamasın);
/// ✓'e dokununca silme onayı. En çok 6 sure tutulur (servis eskisini siler).
class _DownloadButton extends ConsumerWidget {
  final Surah surah;
  final String lang;
  const _DownloadButton({required this.surah, required this.lang});

  Future<void> _confirmDownload(BuildContext context, WidgetRef ref) async {
    final tr = lang == 'tr';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr ? 'Offline indir' : 'Download offline'),
        content: Text(tr
            ? '"${surah.name(lang)}" suresinin ${surah.ayahCount} ayeti cihaza indirilsin mi? Sonra internetsiz dinleyebilirsin (en çok 6 sure saklanır).'
            : 'Download all ${surah.ayahCount} verses of "${surah.name(lang)}" for offline listening? (Up to 6 surahs are kept.)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr ? 'Vazgeç' : 'Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr ? 'İndir' : 'Download')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final verses = await ref.read(versesProvider(surah.number).future);
      final tracks = buildQuranTracks(surah.number, surah.name(lang), verses,
          quranWallpaperArt(ref, surah.number));
      if (tracks.isEmpty || !context.mounted) return;
      final evicted = await ref
          .read(quranDownloadProvider.notifier)
          .download(surah.number, tracks);
      if (evicted != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr
              ? 'Depolama hafif kalsın diye en eski offline sure silindi (en çok 6).'
              : 'Removed the oldest offline surah to save space (max 6).'),
        ));
      }
    } catch (_) {}
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final tr = lang == 'tr';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr ? 'Offline kaydı sil' : 'Remove download'),
        content: Text(tr
            ? '"${surah.name(lang)}" cihazdan silinsin mi? İstediğinde tekrar indirebilirsin.'
            : 'Remove the offline copy of "${surah.name(lang)}"? You can download it again anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr ? 'Vazgeç' : 'Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr ? 'Sil' : 'Remove')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(quranDownloadProvider.notifier).remove(surah.number);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final downloaded = ref.watch(quranDownloadProvider
        .select((s) => s.downloaded.contains(surah.number)));
    final progress = ref.watch(
        quranDownloadProvider.select((s) => s.progress[surah.number]));

    // İndiriliyor → yüzde + dolan halka (bitince ✓ olur).
    if (progress != null) {
      return SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: CircularProgressIndicator(
                  value: progress <= 0 ? null : progress,
                  strokeWidth: 2.5,
                  color: c.gold,
                  backgroundColor: c.gold.withValues(alpha: 0.16),
                ),
              ),
            ),
            Text('${(progress * 100).round()}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.gold, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    // İndirildi → dolu altın daire + ✓ (dokun → silme onayı). Değilse → açık
    // daire + ⬇ (dokun → indirme onayı).
    return SizedBox(
      width: 46,
      height: 46,
      child: Center(
        child: Material(
          color: downloaded ? c.gold : c.gold.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => downloaded
                ? _confirmRemove(context, ref)
                : _confirmDownload(context, ref),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(
                downloaded
                    ? Icons.download_done_rounded
                    : Icons.download_rounded,
                color: downloaded ? c.bg : c.gold,
                size: 22,
              ),
            ),
          ),
        ),
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
              context.go('${Routes.quranReader}/${startSurah.number}'),
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
