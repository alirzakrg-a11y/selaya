import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/geo.dart';

/// Thin wrapper over geolocator with a short-lived cache so back-to-back reads
/// (onboarding → city picker → nearby mosques) return the last fix instantly
/// instead of waiting on a fresh GPS lock each time. City-level precision is
/// plenty for prayer times, so a few minutes of staleness is fine. Returns null
/// on any failure/denial so callers fall back to a manually selected city.
class LocationService {
  LocationService();

  static const _cacheTtl = Duration(minutes: 3);
  LatLng? _posCache;
  DateTime? _posCacheAt;
  ({LatLng pos, String name})? _locCache;
  DateTime? _locCacheAt;

  bool _fresh(DateTime? at) =>
      at != null && DateTime.now().difference(at) < _cacheTtl;

  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LatLng?> currentPosition({bool allowCache = true}) async {
    if (allowCache && _posCache != null && _fresh(_posCacheAt)) {
      return _posCache;
    }
    if (!await ensurePermission()) return null;
    // Medium accuracy + a hard time limit so it never hangs on a precise fix.
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return _cachePos(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // Fall back to the last cached fix (fast) if the live read timed out.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return _cachePos(LatLng(last.latitude, last.longitude));
        }
      } catch (_) {}
      return null;
    }
  }

  LatLng _cachePos(LatLng p) {
    _posCache = p;
    _posCacheAt = DateTime.now();
    return p;
  }

  /// Current position + reverse-geocoded city name (best effort).
  Future<({LatLng pos, String name})?> currentLocation(
      {bool allowCache = true}) async {
    if (allowCache && _locCache != null && _fresh(_locCacheAt)) {
      return _locCache;
    }
    final pos = await currentPosition(allowCache: allowCache);
    if (pos == null) return null;
    String name = '';
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        // İlçe (district) + il (province) → e.g. "İskenderun, Hatay".
        // subAdministrativeArea = ilçe, administrativeArea = il; fall back to
        // locality / whichever part is available.
        final ilce = (m.subAdministrativeArea?.isNotEmpty ?? false)
            ? m.subAdministrativeArea!
            : (m.locality ?? '');
        final il = m.administrativeArea ?? '';
        if (ilce.isNotEmpty && il.isNotEmpty && ilce != il) {
          name = '$ilce, $il';
        } else if (il.isNotEmpty) {
          name = il;
        } else {
          name = ilce;
        }
      }
    } catch (_) {}
    final result = (pos: pos, name: name);
    _locCache = result;
    _locCacheAt = DateTime.now();
    return result;
  }
}

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());
