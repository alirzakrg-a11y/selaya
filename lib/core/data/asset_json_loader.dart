import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single entry point for loading bundled demo JSON. Every JSON-backed
/// repository depends on this, so swapping to Firebase/REST later only
/// touches repository implementations — never call sites.
class AssetJsonLoader {
  const AssetJsonLoader();

  Future<List<dynamic>> loadList(String path) async {
    final raw = await rootBundle.loadString(path);
    return jsonDecode(raw) as List<dynamic>;
  }

  Future<Map<String, dynamic>> loadMap(String path) async {
    final raw = await rootBundle.loadString(path);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Loads a list and maps each element (assumed Map) through [fromJson].
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

final assetJsonLoaderProvider =
    Provider<AssetJsonLoader>((ref) => const AssetJsonLoader());
