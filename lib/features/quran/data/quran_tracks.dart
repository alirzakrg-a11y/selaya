import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/cdn.dart';
import '../../../core/data/content_providers.dart';
import '../../../core/models/content.dart';

/// Çalınabilir tek ayet parçası (sure sesli okuması). Sade Kur'an oynatıcısı
/// için — audio_service'e/medya oynatıcıya BAĞIMLI DEĞİL. (Eski `MediaTrack`
/// audio_handler.dart'taydı; medya oynatıcı tamamen kaldırılınca buraya taşındı.)
class MediaTrack {
  final String id;
  final String url;
  final String title;
  final String artUri; // sure kapağı (duvar kâğıdı) — sade oynatıcı kullanmaz ama tutulur
  const MediaTrack({
    required this.id,
    required this.url,
    required this.title,
    this.artUri = '',
  });
}

/// Bir surenin sesli ayetlerini (Worker proxy) [MediaTrack] listesine çevirir.
/// Okuyucu (`_buildTracks`) ile AYNI mantık; sure listesindeki play butonu da
/// bunu kullanır.
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
