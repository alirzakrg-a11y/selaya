import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/cdn.dart';
import '../../../core/data/content_providers.dart';
import '../../../core/models/content.dart';
import '../../audio_stories/data/audio_handler.dart';

/// Bir surenin sesli ayetlerini (Worker proxy) `MediaTrack` listesine çevirir.
/// Okuyucu (`_buildTracks`) ile AYNI mantık; now-playing'deki ③ "tüm sureler"
/// listesinden başka bir sureye atlamak için ortak kaynak.
List<MediaTrack> buildQuranTracks(
    int surahNumber, String surahName, List<Verse> verses, String art) {
  final audible = [
    for (final v in verses)
      if (v.audio != null) v
  ];
  return [
    for (final v in audible)
      MediaTrack(
        id: '${surahNumber}_${v.ayah}',
        url: '${SelayaCdn.apiBase}/v1/quran-audio/$surahNumber/${v.ayah}',
        title: '$surahName · ${v.ayah}',
        artUri: art,
      ),
  ];
}

/// Sure kapağı = günlük duvar kâğıtlarından sure numarasına göre sabit biri
/// (okuyucudaki `_wallpaperArt` ile aynı).
String quranWallpaperArt(WidgetRef ref, int surahNumber) {
  final fallback =
      '${SelayaCdn.cdnBase}/images/wallpapers/wp_calligraphy_1.jpg';
  final wps = ref.read(wallpapersProvider).value ?? const <Wallpaper>[];
  if (wps.isEmpty) return fallback;
  final img = wps[surahNumber % wps.length].image;
  if (img.startsWith('http')) return img;
  final u = SelayaCdn.urlForAsset(img);
  return u.isNotEmpty ? u : fallback;
}
