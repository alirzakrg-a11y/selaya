import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single entry point for loading bundled demo JSON. Every JSON-backed
/// repository depends on this, so swapping to Firebase/REST later only
/// touches repository implementations — never call sites.
class AssetJsonLoader {
  const AssetJsonLoader();

  /// Bu eşiğin ÜSTÜNDEKİ JSON, ana thread YERİNE bir isolate'te (`compute`)
  /// çözülür → İLK AÇILIŞ + SURE AÇILIŞ DONMASININ kökü. `jsonDecode` SENKRON;
  /// büyük dosyalarda ana thread'de çalışınca UI'ı yüz milisaniyelerce BLOKE
  /// ediyordu — ölçülen boyutlar: daily_inspiration.json 176 KB (Ana Sayfa
  /// açılışta yükler), mosques/<şehir>.json 432 KB'a kadar (konum açıkken en
  /// yakın cami), quran/verses_002.json (Bakara) 337 KB (sure açılışı). İsolate'
  /// te parse → UI bloke olmaz, "donma" gider. Küçük dosyalarda isolate spawn
  /// overhead'i gereksiz olduğundan eşik altı ana thread'de (anlık) çözülür.
  static const _isolateThreshold = 32 * 1024; // 32 KB

  Future<List<dynamic>> loadList(String path) async {
    final raw = await rootBundle.loadString(path);
    return raw.length > _isolateThreshold
        ? compute(_decodeJsonList, raw)
        : _decodeJsonList(raw);
  }

  Future<Map<String, dynamic>> loadMap(String path) async {
    final raw = await rootBundle.loadString(path);
    return raw.length > _isolateThreshold
        ? compute(_decodeJsonMap, raw)
        : _decodeJsonMap(raw);
  }

  /// Loads a list and maps each element (assumed Map) through [fromJson].
  /// NOT: jsonDecode (ağır) isolate'te yapılır (bkz. [loadList]); fromJson
  /// eşlemesi ana thread'de kalır (alan ataması — hafif).
  Future<List<T>> loadModels<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final list = await loadList(path);
    return list
        .map((e) => fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }
}

// compute() üst-düzey/statik fonksiyon ister (isolate entry — closure geçemez).
List<dynamic> _decodeJsonList(String raw) => jsonDecode(raw) as List<dynamic>;
Map<String, dynamic> _decodeJsonMap(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;

final assetJsonLoaderProvider =
    Provider<AssetJsonLoader>((ref) => const AssetJsonLoader());
