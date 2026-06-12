import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Saves wallpapers to the device gallery (uses `gal`) and sets them as the
/// device wallpaper (native WallpaperManager via a MethodChannel).
class GalleryService {
  const GalleryService();

  static const _wpChannel = MethodChannel('selaya/wallpaper');

  /// Görsel baytları: CDN url ise indir (http), paket-içi asset ise yükle.
  /// (Duvar kâğıtları panel/CDN'den geldiği için eskiden `rootBundle.load`
  /// CDN url'sinde HATA veriyordu → indir/ayarla çalışmıyordu.)
  Future<Uint8List?> _bytes(String pathOrUrl) async {
    if (pathOrUrl.startsWith('http')) {
      final r = await http.get(Uri.parse(pathOrUrl));
      return r.statusCode == 200 ? r.bodyBytes : null;
    }
    final d = await rootBundle.load(pathOrUrl);
    return d.buffer.asUint8List();
  }

  Future<bool> saveAsset(String pathOrUrl, {String album = 'SELAYA'}) async {
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) return false;
      }
      final bytes = await _bytes(pathOrUrl);
      if (bytes == null) return false;
      await Gal.putImageBytes(bytes, album: album);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Yerel bir PNG/JPG dosyasını (ör. yakalanmış tebrik kartı) galeriye kaydet.
  Future<bool> saveImageFile(String path, {String album = 'SELAYA'}) async {
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) return false;
      }
      await Gal.putImage(path, album: album);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Videoyu galeriye kaydet (CDN url → indir → temp .mp4 → galeri).
  Future<bool> saveVideo(String pathOrUrl, {String album = 'SELAYA'}) async {
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) return false;
      }
      final bytes = await _bytes(pathOrUrl);
      if (bytes == null) return false;
      final dir = await getTemporaryDirectory();
      final f = await File(
              '${dir.path}/selaya_${DateTime.now().millisecondsSinceEpoch}.mp4')
          .writeAsBytes(bytes);
      await Gal.putVideo(f.path, album: album);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cihaz duvar kâğıdı olarak ayarla. [target]: 'home' | 'lock' | 'both'.
  Future<bool> setWallpaper(String pathOrUrl, String target) async {
    try {
      final bytes = await _bytes(pathOrUrl);
      if (bytes == null) return false;
      final ok = await _wpChannel.invokeMethod<bool>(
          'setWallpaper', {'bytes': bytes, 'target': target});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}

final galleryServiceProvider =
    Provider<GalleryService>((ref) => const GalleryService());
