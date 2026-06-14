import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../utils/geo.dart';
import 'location_service.dart';
import 'permission_service.dart';

/// A real mosque near the user, from OpenStreetMap (with coordinates → distance).
class NearbyMosque {
  final String name;
  final double lat;
  final double lng;
  final double distanceKm;
  const NearbyMosque(this.name, this.lat, this.lng, this.distanceKm);
}

/// Finds nearby mosques via the free OpenStreetMap Overpass API (no API key).
/// This solves "nearest mosque" since the Diyanet dataset has no coordinates.
class OverpassService {
  const OverpassService();

  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// Expands the search radius until enough results are found.
  Future<List<NearbyMosque>> findNearby(LatLng pos) async {
    for (final radius in [2500, 6000, 15000]) {
      final result = await _query(pos, radius);
      if (result.length >= 8 || radius == 15000) return result;
    }
    return const [];
  }

  Future<List<NearbyMosque>> _query(LatLng pos, int radius) async {
    final q = '[out:json][timeout:25];'
        '(node["amenity"="place_of_worship"]["religion"="muslim"](around:$radius,${pos.latitude},${pos.longitude});'
        'way["amenity"="place_of_worship"]["religion"="muslim"](around:$radius,${pos.latitude},${pos.longitude}););'
        'out center 150;';
    for (final url in _endpoints) {
      try {
        final resp = await http
            .post(
              Uri.parse(url),
              headers: const {
                'User-Agent': 'SELAYA-App/1.0 (Islamic prayer companion)',
              },
              body: {'data': q},
            )
            .timeout(const Duration(seconds: 30));
        if (resp.statusCode != 200) continue;
        // JSON çözme + 150 elemana kadar mesafe hesabı ANA İZOLATTA donmaya yol
        // açıyordu (ilk açılışta "en yakın cami" yüklenirken — kullanıcı bildirdi
        // 2026-06-14) → isolate'te (compute) çöz, ana thread bloklanmasın.
        return await compute(
            _parseOverpassMosques, (resp.body, pos.latitude, pos.longitude));
      } catch (_) {
        continue; // try next mirror
      }
    }
    return const [];
  }
}

/// Overpass yanıtını (JSON) isolate'te çözer: jsonDecode + 150 elemana kadar
/// ayrıştırma/mesafe/sıralama ana thread'i bloklamasın (ilk-açılış donması).
/// Arg: (yanıt gövdesi, kullanıcı enlem, kullanıcı boylam).
List<NearbyMosque> _parseOverpassMosques((String, double, double) arg) {
  final (body, lat, lng) = arg;
  final pos = LatLng(lat, lng);
  final data = jsonDecode(body) as Map<String, dynamic>;
  final elements = (data['elements'] as List?) ?? const [];
  final out = <NearbyMosque>[];
  final seen = <String>{};
  for (final e in elements) {
    final m = (e as Map).cast<String, dynamic>();
    final tags = (m['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    double? la, lo;
    if (m['lat'] != null) {
      la = (m['lat'] as num).toDouble();
      lo = (m['lon'] as num).toDouble();
    } else if (m['center'] is Map) {
      la = ((m['center'] as Map)['lat'] as num).toDouble();
      lo = ((m['center'] as Map)['lon'] as num).toDouble();
    }
    if (la == null || lo == null) continue;
    final name = (tags['name'] ?? tags['name:tr'] ?? 'Cami').toString();
    final key = '${la.toStringAsFixed(5)},${lo.toStringAsFixed(5)}';
    if (!seen.add(key)) continue;
    out.add(NearbyMosque(name, la, lo, distanceKm(pos, LatLng(la, lo))));
  }
  out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return out;
}

final overpassServiceProvider =
    Provider<OverpassService>((ref) => const OverpassService());

/// The single nearest mosque to the user (GPS + OSM), cached for the session so
/// the home-screen card doesn't re-query on every rebuild.
/// `granted:false` → kart "Konum izni gerekli" gösterir (izin İSTEMEZ — pasif
/// kart; istek akışı cami ekranında). `granted:true, mosque:null` → gizlenir.
/// 8 sn toplam zaman aşımı: GPS/ağ asılı kalırsa yükleniyor spinner'ı sonsuza
/// dek dönmesin (sürekli animasyon = sürekli frame üretimi — perf turu 2).
final nearestMosqueProvider =
    FutureProvider<({bool granted, NearbyMosque? mosque})>((ref) async {
  // Başarısız sonuç (izin yok / zaman aşımı / boş) YAPIŞMASIN: provider
  // keepAlive olduğundan bir kez null'a düşünce kart sonsuza dek "yok"
  // kalıyordu (cami ekranına girip izin verip/konum çözüp dönünce bile —
  // regresyon, kullanıcı bildirdi). 1 dk'da bir kendini tazeler; konum
  // cache'i (3 dk) dolu olduğundan yeniden deneme anında sonuçlanır,
  // başarıda timer kurulmaz.
  void retrySoon() {
    final t = Timer(const Duration(minutes: 1), ref.invalidateSelf);
    ref.onDispose(t.cancel);
  }

  if (!await ref.read(permissionServiceProvider).locationGranted()) {
    retrySoon();
    return (granted: false, mosque: null);
  }
  try {
    final mosque = await () async {
      final pos = await ref.read(locationServiceProvider).currentPosition();
      if (pos == null) return null;
      final list = await ref.read(overpassServiceProvider).findNearby(pos);
      return list.isEmpty ? null : list.first;
    }()
        .timeout(const Duration(seconds: 8));
    if (mosque == null) retrySoon();
    return (granted: true, mosque: mosque);
  } on TimeoutException {
    retrySoon();
    return (granted: true, mosque: null);
  }
});
