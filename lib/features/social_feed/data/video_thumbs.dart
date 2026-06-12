import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Posteri olmayan videonun KENDİ karesinden kapak üretir (native
/// MediaMetadataRetriever, ~1.5sn'deki kare, WEBP cache). Dönen değer yerel
/// dosya yolu; üretilemezse null (UI nötr kapakla devam eder).
final videoThumbProvider =
    FutureProvider.family<String?, String>((ref, url) async {
  if (!url.startsWith('http')) return null;
  try {
    final p = await const MethodChannel('selaya/widget')
        .invokeMethod<String>('videoThumb', {'url': url});
    return (p == null || p.isEmpty) ? null : p;
  } catch (_) {
    return null;
  }
});
