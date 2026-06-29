import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/data/likes_service.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/router/routes.dart';
import '../../../core/share/share_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../quran/data/quran_favorites.dart';
import '../../wallpapers/presentation/wallpapers_screen.dart';

typedef _TextItem = ({String arabic, String text, String source, String label});

/// "Beğendiklerim" — kalbe dokunduğun her şey (ayet/hadis/dua/video/duvar kâğıdı)
/// tek yerde. Beğeniler hesaba senkronlanır (likedKeys), burada da görünür.
class LikedScreen extends ConsumerStatefulWidget {
  const LikedScreen({super.key});
  @override
  ConsumerState<LikedScreen> createState() => _LikedScreenState();
}

class _LikedScreenState extends ConsumerState<LikedScreen> {
  String _filter = 'all'; // tür filtresi: all/surahs/videos/verses/hadiths/duas/wallpapers
  bool _show(String k) => _filter == 'all' || _filter == k;

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    // Beğeniler (kalp) + İlham ekranındaki YER İMLERİ (bookmark) — ikisi de aynı
    // anahtar formatında ('verse:id' / 'hadith:id' / 'dua:id'); birleştirip
    // Beğendiklerim'de birlikte gösteriyoruz ("ne işaretlediysem burada olsun").
    final inspFavs =
        ref
            .watch(sharedPreferencesProvider)
            .getStringList(PrefKeys.inspirationFavorites) ??
        const <String>[];
    final liked = {...ref.watch(likedKeysProvider), ...inspFavs};

    final insp =
        ref.watch(inspirationProvider).value ?? const <InspirationItem>[];
    final hadiths = ref.watch(hadithsProvider).value ?? const <Hadith>[];
    final duas = ref.watch(duasProvider).value ?? const <Dua>[];
    final feed = ref.watch(feedProvider).value ?? const <FeedItem>[];
    final walls = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];

    final verses = <_TextItem>[
      for (final i in insp)
        if (i.type == 'verse' && liked.contains('verse:${i.id}'))
          (
            arabic: i.arabic,
            text: i.text(lang),
            source: i.reference,
            label: '',
          ),
    ];
    final hadithItems = <_TextItem>[
      for (final i in insp)
        if (i.type == 'hadith' && liked.contains('hadith:${i.id}'))
          (
            arabic: i.arabic,
            text: i.text(lang),
            source: i.reference,
            label: '',
          ),
      for (final h in hadiths)
        if (liked.contains('hadith:${h.id}'))
          (
            arabic: h.arabic,
            text: h.text(lang),
            source: h.collection,
            label: '',
          ),
    ];
    // Dualar: AKIŞ'taki beğeniler + Dualar EKRANINDAKİ kalpler (duaFavorites)
    // — "ne beğenirsem Beğendiklerim'e düşsün". Metne göre tekrar ayıklanır.
    final duaFavs =
        (ref
                    .watch(sharedPreferencesProvider)
                    .getStringList(PrefKeys.duaFavorites) ??
                const <String>[])
            .toSet();
    final seenDua = <String>{};
    final duaItems = <_TextItem>[
      for (final i in insp)
        if (i.type == 'dua' &&
            liked.contains('dua:${i.id}') &&
            seenDua.add(i.text(lang).trim()))
          (
            arabic: i.arabic,
            text: i.text(lang),
            source: i.reference,
            label: '',
          ),
      for (final d in duas)
        if ((liked.contains('dua:${d.id}') || duaFavs.contains(d.id)) &&
            seenDua.add(d.text(lang).trim()))
          (
            arabic: d.arabic,
            text: d.text(lang),
            source: d.source,
            label: d.title(lang),
          ),
    ];
    // Sure favorileri (Kur'an'daki kalpler) — dokun → o sureye git.
    final surahFavs = ref.watch(quranFavoritesProvider);
    final allSurahs = ref.watch(surahsProvider).value ?? const <Surah>[];
    final likedSurahs = allSurahs
        .where((s) => surahFavs.contains(s.number))
        .toList();
    final vids = [
      for (final f in feed)
        if (liked.contains('feed:${f.id}')) f,
    ];
    final likedWalls = [
      for (final w in walls)
        if (liked.contains('wallpaper:${w.id}')) w,
    ];
    // Sesli hikâye favorileri ("catId:index") → kategori + bölümü çöz (favoriler
    // likedKeys değil ayrı prefs'te; burada görünsün ki "ne beğenirsem burada").
    final audioFavs = ref
            .watch(sharedPreferencesProvider)
            .getStringList(PrefKeys.favoriteAudio) ??
        const <String>[];
    final audioCats =
        ref.watch(audioStoriesProvider).value ?? const <AudioStoryCategory>[];
    final likedAudio =
        <({String catId, int index, AudioStoryCategory cat, AudioEpisode ep})>[];
    for (final key in audioFavs) {
      final ci = key.lastIndexOf(':');
      if (ci <= 0) continue;
      final catId = key.substring(0, ci);
      final idx = int.tryParse(key.substring(ci + 1));
      if (idx == null) continue;
      AudioStoryCategory? cat;
      for (final ct in audioCats) {
        if (ct.id == catId) {
          cat = ct;
          break;
        }
      }
      if (cat == null || idx < 0 || idx >= cat.episodes.length) continue;
      likedAudio
          .add((catId: catId, index: idx, cat: cat, ep: cat.episodes[idx]));
    }
    final total =
        verses.length +
        hadithItems.length +
        duaItems.length +
        vids.length +
        likedWalls.length +
        likedSurahs.length +
        likedAudio.length;

    // Tür filtresi çipleri (yalnız dolu kategoriler).
    final cats = <(String, String, int)>[
      if (likedSurahs.isNotEmpty)
        ('surahs', 'liked.surahs'.tr(), likedSurahs.length),
      if (vids.isNotEmpty) ('videos', 'liked.videos'.tr(), vids.length),
      if (verses.isNotEmpty) ('verses', 'liked.verses'.tr(), verses.length),
      if (hadithItems.isNotEmpty)
        ('hadiths', 'liked.hadiths'.tr(), hadithItems.length),
      if (duaItems.isNotEmpty) ('duas', 'liked.duas'.tr(), duaItems.length),
      if (likedWalls.isNotEmpty)
        ('wallpapers', 'liked.wallpapers'.tr(), likedWalls.length),
      if (likedAudio.isNotEmpty)
        ('audio', 'audioStories.title'.tr(), likedAudio.length),
    ];
    if (_filter != 'all' && !cats.any((e) => e.$1 == _filter)) _filter = 'all';

    return SelayaScaffold(
      title: 'liked.title'.tr(),
      showBack: true,
      body: total == 0
          ? _empty(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.md,
                AppSpacing.base,
                AppSpacing.xxxl,
              ),
              children: [
                if (cats.length >= 2) _filterChips(cats),
                if (_show('surahs') && likedSurahs.isNotEmpty) ...[
                  _SectionTitle('liked.surahs'.tr(), likedSurahs.length),
                  for (final s in likedSurahs)
                    _MediaCard(
                      image: '',
                      title:
                          '${s.number}. ${s.name(lang)} · ${'quran.ayahCount'.tr(args: [s.ayahCount.toString()])}',
                      icon: Icons.menu_book_rounded,
                      onTap: () =>
                          context.push('${Routes.quranReader}/${s.number}'),
                    ),
                  const Gap.lg(),
                ],
                if (_show('videos') && vids.isNotEmpty) ...[
                  _SectionTitle('liked.videos'.tr(), vids.length),
                  for (final f in vids)
                    _MediaCard(
                      image: f.poster,
                      title: _videoLabel(f, lang),
                      icon: Icons.play_circle_fill_rounded,
                      onTap: () =>
                          context.push(Routes.feed, extra: feed.indexOf(f)),
                    ),
                  const Gap.lg(),
                ],
                if (_show('verses'))
                  ..._textSection('liked.verses'.tr(), verses),
                if (_show('hadiths'))
                  ..._textSection('liked.hadiths'.tr(), hadithItems),
                if (_show('duas')) ..._textSection('liked.duas'.tr(), duaItems),
                if (_show('wallpapers') && likedWalls.isNotEmpty) ...[
                  _SectionTitle('liked.wallpapers'.tr(), likedWalls.length),
                  for (final w in likedWalls)
                    _MediaCard(
                      image: w.image,
                      title: w.title(lang).isEmpty
                          ? 'wallpapers.title'.tr()
                          : w.title(lang),
                      icon: Icons.wallpaper_rounded,
                      // ⑪ Beğenilen duvar kâğıdı → o görseli AÇ (eskiden sadece
                      // listeye gidiyordu); kullanıcı beğendikleri arasında gezer.
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => WallpaperDetail(
                            list: likedWalls,
                            index: likedWalls.indexOf(w),
                          ),
                        ),
                      ),
                    ),
                  const Gap.lg(),
                ],
                if (_show('audio') && likedAudio.isNotEmpty) ...[
                  _SectionTitle('audioStories.title'.tr(), likedAudio.length),
                  for (final a in likedAudio)
                    _MediaCard(
                      image: a.ep.cover.isEmpty ? a.cat.cover : a.ep.cover,
                      title: a.ep.title(lang),
                      icon: Icons.headphones_rounded,
                      onTap: () => context.push(
                        '${Routes.audioStories}/player/${a.catId}/${a.index}',
                      ),
                    ),
                  const Gap.lg(),
                ],
              ],
            ),
    );
  }

  /// Tür filtre çipleri (Tümü + dolu kategoriler).
  Widget _filterChips(List<(String, String, int)> cats) {
    final c = context.colors;
    Widget chip(String key, String label, bool sel) => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: GestureDetector(
            onTap: () => setState(() => _filter = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? c.gold : c.surfaceAlt,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: sel ? c.gold : c.border),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: sel ? c.onGold : c.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            chip('all', 'xt.lkFilterAll'.tr(), _filter == 'all'),
            for (final (key, label, count) in cats)
              chip(key, '$label · $count', _filter == key),
          ],
        ),
      ),
    );
  }

  List<Widget> _textSection(String title, List<_TextItem> items) {
    if (items.isEmpty) return const <Widget>[];
    return [
      _SectionTitle(title, items.length),
      for (final it in items)
        _TextCard(
          arabic: it.arabic,
          text: it.text,
          reference: it.source,
          label: it.label.isEmpty ? title : it.label,
        ),
      const Gap.lg(),
    ];
  }

  /// Video etiketi: açıklama (caption) varsa onu; yoksa başlık (UUID/dosya-id
  /// değilse); o da yoksa genel "Video".
  String _videoLabel(FeedItem f, String lang) {
    final cap = f.caption(lang).trim();
    if (cap.isNotEmpty) return cap;
    final t = f.title(lang).trim();
    final looksLikeId = RegExp(r'^[0-9a-fA-F-]{30,}$').hasMatch(t);
    return (t.isNotEmpty && !looksLikeId) ? t : 'liked.video'.tr();
  }

  Widget _empty(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 64,
              color: c.textTertiary,
            ),
            const Gap.md(),
            Text(
              'liked.empty'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final int count;
  const _SectionTitle(this.text, this.count);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
        top: AppSpacing.xs,
      ),
      child: Text(
        '$text · $count',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: c.gold,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  final String arabic, text, reference, label;
  const _TextCard({
    required this.arabic,
    required this.text,
    required this.reference,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SelayaCard(
        onTap: () => showVerseShareSheet(
          context,
          arabic: arabic.isEmpty ? null : arabic,
          text: text,
          reference: reference,
          label: label,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (arabic.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: Text(
                  arabic,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.arabic(
                    fontSize: 20,
                    color: c.textPrimary,
                  ),
                ),
              ),
              const Gap.sm(),
            ],
            Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textSecondary, height: 1.45),
            ),
            if (reference.isNotEmpty) ...[
              const Gap.xs(),
              Text(
                reference,
                style: TextStyle(
                  color: c.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final String image, title;
  final IconData icon;
  final VoidCallback onTap;
  const _MediaCard({
    required this.image,
    required this.title,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SelayaCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.rMd,
              child: SizedBox(
                width: 56,
                height: 56,
                child: image.isEmpty
                    ? Container(
                        color: c.gold.withValues(alpha: 0.14),
                        child: Icon(icon, color: c.gold, size: 26),
                      )
                    : AppImage.cdn(image),
              ),
            ),
            const Gap.md(),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Icon(icon, color: c.gold),
          ],
        ),
      ),
    );
  }
}
