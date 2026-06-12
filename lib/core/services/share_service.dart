import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Where a share should go. Anything other than [system] is attempted as a
/// direct hand-off to that app and silently falls back to the OS share sheet
/// when the app isn't installed or the platform can't target it.
enum ShareTarget { whatsapp, instagram, facebook, system }

/// One share API for the whole app. Captures branded cards to a PNG and shares
/// them either directly to a target app (via a small native MethodChannel) or
/// through the system share sheet. Direct hand-off works best on Android
/// (`Intent.ACTION_SEND` + `setPackage`) and for Instagram Stories on iOS; every
/// other case degrades gracefully to the system sheet.
class ShareService {
  const ShareService();

  static const _channel = MethodChannel('com.selaya.app/share');

  /// Renders a [RepaintBoundary] (keyed by [boundaryKey]) to a ~1080px-wide PNG
  /// in the temp dir and returns its path (null if the boundary isn't mounted).
  Future<String?> captureBoundary(GlobalKey boundaryKey) async {
    final ctx = boundaryKey.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final pr = boundary.size.width > 0 ? (1080 / boundary.size.width) : 3.0;
    final image = await boundary.toImage(pixelRatio: pr);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final file = await File(
            '${dir.path}/selaya_share_${DateTime.now().millisecondsSinceEpoch}.png')
        .writeAsBytes(bytes.buffer.asUint8List());
    return file.path;
  }

  /// Shares an image [path] to [target]. For non-system targets it tries a direct
  /// native hand-off first and falls back to the share sheet on any failure.
  Future<void> shareImageFile(
    String path, {
    required String text,
    ShareTarget target = ShareTarget.system,
    Rect? origin,
  }) async {
    if (target != ShareTarget.system) {
      try {
        final ok = await _channel.invokeMethod<bool>('shareImageToApp', {
          'target': target.name,
          'path': path,
          'text': text,
        });
        if (ok == true) return;
      } catch (_) {
        // Channel missing / app not installed / platform can't target → sheet.
      }
    }
    await _systemSheet(path, text, origin);
  }

  /// Copies a bundled asset image to a temp file so it can be shared like any
  /// other image (used by the sticker grid). Returns null on failure.
  Future<String?> assetToTempFile(String assetPath) async {
    try {
      final bytes = await rootBundle.load(assetPath);
      final dir = await getTemporaryDirectory();
      final name = assetPath.split('/').last;
      final file = await File(
              '${dir.path}/selaya_sticker_${DateTime.now().millisecondsSinceEpoch}_$name')
          .writeAsBytes(bytes.buffer.asUint8List());
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Copies a bundled video asset to a temp file and shares it as a real video
  /// (so WhatsApp, Instagram, Telegram, etc. each receive the actual .mp4) — or
  /// shares the link directly when [source] is a remote URL. Silent on failure.
  Future<void> shareVideo(String source,
      {required String text,
      String? subject,
      String? fileName,
      Rect? origin}) async {
    try {
      Uint8List data;
      String name;
      if (source.startsWith('http')) {
        // Remote (CDN) → İNDİR ve gerçek .mp4 olarak paylaş. (Eskiden sadece
        // url'yi metin paylaşıyordu → "paylaşınca api adresi çıkıyordu".)
        final res = await http.get(Uri.parse(source));
        if (res.statusCode != 200) {
          await SharePlus.instance.share(ShareParams(
              text: '$text\n$source',
              subject: subject,
              sharePositionOrigin: origin));
          return;
        }
        data = res.bodyBytes;
        // Dosya adı = video açıklaması (anlamlı), yoksa marka adı.
        name = '${_safeFileName(fileName)}.mp4';
      } else {
        final bytes = await rootBundle.load(source);
        data = bytes.buffer.asUint8List();
        name = source.split('/').last;
      }
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/$name').writeAsBytes(data);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'video/mp4')],
        text: text,
        subject: subject,
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      // İndirme / temp yazma / paylaşım hedefi yok → sessiz.
    }
  }

  /// Paylaşılan dosyaya anlamlı ad verir (video açıklamasından);
  /// emoji/sembolleri temizler, 40 karakterle sınırlar.
  String _safeFileName(String? s) {
    final base = (s ?? '')
        .replaceAll(RegExp(r'[^A-Za-z0-9ğüşıöçĞÜŞİÖÇ \-_]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final clipped = base.length > 40 ? base.substring(0, 40).trim() : base;
    return clipped.isEmpty ? 'SELAYA' : clipped;
  }

  /// Captures [boundaryKey] then shares it; convenience for the common path.
  Future<void> shareBoundary(
    GlobalKey boundaryKey, {
    required String text,
    ShareTarget target = ShareTarget.system,
    Rect? origin,
  }) async {
    final path = await captureBoundary(boundaryKey);
    if (path == null) return;
    await shareImageFile(path, text: text, target: target, origin: origin);
  }

  Future<void> _systemSheet(String path, String text, Rect? origin) async {
    final params = ShareParams(
      files: [XFile(path, mimeType: 'image/png')],
      text: text,
      sharePositionOrigin: origin,
    );
    await SharePlus.instance.share(params);
  }
}

final shareServiceProvider =
    Provider<ShareService>((ref) => const ShareService());
