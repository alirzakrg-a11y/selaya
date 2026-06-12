import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/cdn.dart';
import '../di/providers.dart';

/// Tek bir uzak içerik öğesi (CDN'deki dosya + meta).
class ContentItem {
  final String id;
  final String collection;
  final String kind; // image | video | audio
  final String url; // tam CDN URL
  final String? thumb;
  final String? title;
  final String? subtitle;
  final Map<String, dynamic>? extra;

  const ContentItem({
    required this.id,
    required this.collection,
    required this.kind,
    required this.url,
    this.thumb,
    this.title,
    this.subtitle,
    this.extra,
  });

  /// Offline yedeği için paket-içi asset yolu (yeni/panel içeriğinde olmayabilir).
  String get assetFallback => SelayaCdn.assetForUrl(url);

  factory ContentItem.fromJson(String collection, Map<String, dynamic> j) {
    return ContentItem(
      id: (j['id'] ?? '').toString(),
      collection: collection,
      kind: (j['kind'] ?? 'image').toString(),
      url: (j['url'] ?? '').toString(),
      thumb: j['thumb'] as String?,
      title: j['title'] as String?,
      subtitle: j['subtitle'] as String?,
      extra: j['extra'] is Map
          ? Map<String, dynamic>.from(j['extra'] as Map)
          : null,
    );
  }
}

class SelayaManifest {
  final Map<String, List<ContentItem>> collections;
  const SelayaManifest(this.collections);
  List<ContentItem> of(String c) => collections[c] ?? const [];
}

const String _manifestCacheKey = 'selaya_manifest_cache_v1';

/// Oturum içi tazeleme kilidi: arka plan yenilemesi en fazla 3 dakikada bir
/// (invalidateSelf → rebuild → tekrar tazeleme döngüsünü de keser).
DateTime? _lastManifestRefresh;

SelayaManifest _parseManifest(String body) {
  final j = jsonDecode(body) as Map<String, dynamic>;
  final cols = (j['collections'] as Map<String, dynamic>?) ?? const {};
  final out = <String, List<ContentItem>>{};
  cols.forEach((k, v) {
    if (v is List) {
      out[k] = v
          .whereType<Map>()
          .map((e) => ContentItem.fromJson(k, Map<String, dynamic>.from(e)))
          .toList();
    }
  });
  return SelayaManifest(out);
}

/// Uzak içerik manifesti — ÖNBELLEK ÖNCELİKLİ:
/// önceki kopya varsa ANINDA onu döner (ağ beklenmez → açılışta gecikme yok),
/// ağdan tazeleme arka planda yapılır; içerik değiştiyse provider yenilenir.
/// Yalnızca ilk kurulumda (önbellek yokken) ağ beklenir. Asla hata fırlatmaz.
final manifestProvider = FutureProvider<SelayaManifest>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final cached = prefs.getString(_manifestCacheKey);

  if (cached != null && cached.isNotEmpty) {
    _refreshInBackground(ref, prefs, cached);
    try {
      // Binlerce öğeli JSON ana akışı (UI) kilitlemesin → ayrı isolate'ta parse.
      return await compute(_parseManifest, cached);
    } catch (_) {/* bozuk önbellek → ağdan dene */}
  }

  try {
    final res = await http
        .get(Uri.parse(SelayaCdn.manifestUrl))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      await prefs.setString(_manifestCacheKey, res.body);
      return await compute(_parseManifest, res.body);
    }
  } catch (e) {
    if (kDebugMode) debugPrint('SELAYA manifest fetch failed: $e');
  }
  return const SelayaManifest({});
});

/// Manifesti sessizce ağdan çeker; gövde DEĞİŞTİYSE kaydedip provider'ı
/// yeniler (UI o ana dek eski içeriği göstermeye devam eder — titreme yok).
void _refreshInBackground(Ref ref, SharedPreferences prefs, String old) {
  final now = DateTime.now();
  if (_lastManifestRefresh != null &&
      now.difference(_lastManifestRefresh!) < const Duration(minutes: 3)) {
    return;
  }
  _lastManifestRefresh = now;
  unawaited(() async {
    try {
      final res = await http
          .get(Uri.parse(SelayaCdn.manifestUrl))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != old) {
        await prefs.setString(_manifestCacheKey, res.body);
        ref.invalidateSelf();
      }
    } catch (_) {/* çevrimdışı vb. — önbellek zaten ekranda */}
  }());
}

/// Bir koleksiyonun öğeleri (yükleniyor/hata durumunda boş liste döner).
/// Riverpod 3'te `.value` arka plan tazelemesi sırasında ÖNCEKİ veriyi
/// korur → invalidateSelf anında listeler boşalmaz, titreme olmaz.
final collectionProvider =
    Provider.family<List<ContentItem>, String>((ref, name) {
  return ref.watch(manifestProvider).value?.of(name) ?? const [];
});
