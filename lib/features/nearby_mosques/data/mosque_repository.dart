import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/asset_json_loader.dart';

/// One mosque (Diyanet directory). Stored compactly as [name, district, address, flags9].
/// flags order: historic, selatin, disabledWudu, disabledToilet, signLanguage,
/// wheelchair, morningGathering, quranCourse, womenArea.
class Mosque {
  final String name;
  final String district;
  final String address;
  final String flags;
  const Mosque(this.name, this.district, this.address, this.flags);

  bool _f(int i) => i < flags.length && flags[i] == '1';
  bool get historic => _f(0);
  bool get selatin => _f(1);
  bool get disabledWudu => _f(2);
  bool get disabledToilet => _f(3);
  bool get signLanguage => _f(4);
  bool get wheelchair => _f(5);
  bool get morningGathering => _f(6);
  bool get quranCourse => _f(7);
  bool get womenArea => _f(8);
  bool get disabledAccess => disabledWudu || disabledToilet || signLanguage || wheelchair;

  factory Mosque.fromArray(List<dynamic> a) =>
      Mosque(a[0] as String, a[1] as String? ?? '', a[2] as String? ?? '',
          a[3] as String? ?? '000000000');
}

class Province {
  final String slug;
  final String name;
  final int count;
  const Province(this.slug, this.name, this.count);

  factory Province.fromJson(Map<String, dynamic> j) =>
      Province(j['slug'] as String, j['name'] as String, j['count'] as int);
}

/// All 81 provinces with mosque counts (from index.json).
final mosqueProvincesProvider = FutureProvider<List<Province>>((ref) async {
  final loader = ref.watch(assetJsonLoaderProvider);
  final list = await loader.loadList('assets/data/mosques/index.json');
  return list
      .map((e) => Province.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
});

/// Mosques for one province (loaded on demand).
final provinceMosquesProvider =
    FutureProvider.family<List<Mosque>, String>((ref, slug) async {
  final loader = ref.watch(assetJsonLoaderProvider);
  final list = await loader.loadList('assets/data/mosques/$slug.json');
  return list.map((e) => Mosque.fromArray(e as List<dynamic>)).toList();
});
