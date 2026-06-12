import 'dart:convert';

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
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
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
          final name =
              (tags['name'] ?? tags['name:tr'] ?? 'Cami').toString();
          final key = '${la.toStringAsFixed(5)},${lo.toStringAsFixed(5)}';
          if (!seen.add(key)) continue;
          out.add(NearbyMosque(name, la, lo, distanceKm(pos, LatLng(la, lo))));
        }
        out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        return out;
      } catch (_) {
        continue; // try next mirror
      }
    }
    return const [];
  }
}

final overpassServiceProvider =
    Provider<OverpassService>((ref) => const OverpassService());

/// The single nearest mosque to the user (GPS + OSM), cached for the session so
/// the home-screen card doesn't re-query on every rebuild. Resolves to null when
/// location is unavailable/denied or nothing is found — the card then hides.
/// Permission is only *checked* (never requested) so this passive card never
/// triggers a prompt; the dedicated mosque screen handles asking.
final nearestMosqueProvider = FutureProvider<NearbyMosque?>((ref) async {
  if (!await ref.read(permissionServiceProvider).locationGranted()) return null;
  final pos = await ref.read(locationServiceProvider).currentPosition();
  if (pos == null) return null;
  final list = await ref.read(overpassServiceProvider).findNearby(pos);
  return list.isEmpty ? null : list.first;
});
