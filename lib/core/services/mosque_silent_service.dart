import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import 'location_service.dart';
import 'overpass_service.dart';
import 'permission_service.dart';
import 'smart_silent_service.dart';

/// Bridges to the native mosque geofence (Android only).
///
/// Registers circular geofences around the nearest mosques; the native side
/// silences the ringer on ENTER/DWELL and restores it on EXIT (reusing the
/// Smart Silent DND/notification-policy plumbing, but with its own muted-state
/// so the two never clobber each other). An immediate foreground proximity
/// apply also runs on enable/resume, so it still works when background-location
/// is denied — just only while the app is opened near a mosque.
class MosqueSilentService {
  static const MethodChannel _ch = MethodChannel('selaya/mosque_silent');

  bool get _supported => Platform.isAndroid;

  /// (Re)register geofences for [mosques]. Replaces any previous set.
  Future<void> register(
      List<({String id, double lat, double lng, double radius})>
          mosques) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod('register', {
        'mosques': [
          for (final m in mosques)
            {'id': m.id, 'lat': m.lat, 'lng': m.lng, 'radius': m.radius}
        ],
      });
    } catch (_) {}
  }

  /// Immediately mute ([near] = true) or restore ([near] = false) based on the
  /// current foreground proximity check.
  Future<void> applyNow(bool near) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod('applyNow', {'near': near});
    } catch (_) {}
  }

  /// Remove all geofences and restore the ringer if we muted it.
  Future<void> clear() async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod('clear');
    } catch (_) {}
  }
}

final mosqueSilentServiceProvider =
    Provider<MosqueSilentService>((ref) => MosqueSilentService());

/// On/off state + orchestration for "auto-silence near a mosque".
class MosqueSilentController extends Notifier<bool> {
  static const _radiusM = 80.0; // geofence radius — mosque footprint + courtyard
  static const _maxMosques = 20; // cap geofences (Android system limit is 100)

  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(PrefKeys.mosqueSilent) ??
      false;

  Future<void> setEnabled(bool v) async {
    await ref.read(sharedPreferencesProvider).setBool(PrefKeys.mosqueSilent, v);
    state = v;
    if (v) {
      await refresh(interactive: true);
    } else {
      await ref.read(mosqueSilentServiceProvider).clear();
    }
  }

  /// Re-fetch nearby mosques, (re)register geofences, and apply the immediate
  /// proximity state. Called on enable and on every app resume; no-op when off.
  /// [interactive] (only on the explicit enable) may prompt for permissions.
  Future<void> refresh({bool interactive = false}) async {
    if (!state) return;
    // Need DND / notification-policy access to change the ringer (shared with
    // the time-based Smart Silent).
    final silent = ref.read(smartSilentServiceProvider);
    if (!await silent.hasAccess()) {
      if (interactive) await silent.requestAccess();
      return;
    }
    final perm = ref.read(permissionServiceProvider);
    if (interactive) {
      // Foreground location first (geolocator dialog) …
      if (!await perm.locationGranted()) {
        final out = await perm.requestLocation();
        if (!out.isGranted) return;
      }
      // … then the separate "Allow all the time" grant (Android 11+ sends the
      // user to Settings) so the geofence can fire in the background. Best
      // effort — without it we silently fall back to the foreground check.
      await perm.requestBackgroundLocation();
    }
    if (!await perm.locationGranted()) return;
    // Fresh fix on the explicit enable; the short location cache is fine on
    // resume (and avoids a GPS lock on every app open).
    final pos = await ref
        .read(locationServiceProvider)
        .currentPosition(allowCache: !interactive);
    if (pos == null) return;
    final mosques = await ref.read(overpassServiceProvider).findNearby(pos);
    if (mosques.isEmpty) return;
    final nearest = mosques.take(_maxMosques).toList();
    final svc = ref.read(mosqueSilentServiceProvider);
    // GeofencingClient.addGeofences throws (silently caught) without background
    // location, and geofences only TRIGGER in the background when it's granted.
    // So register only when "Allow all the time" is on; otherwise clear any
    // stale geofences and rely purely on the foreground proximity check below.
    if (await perm.backgroundLocationGranted()) {
      await svc.register([
        for (var i = 0; i < nearest.length; i++)
          (
            id: 'mosque_$i',
            lat: nearest[i].lat,
            lng: nearest[i].lng,
            radius: _radiusM,
          ),
      ]);
    } else {
      await svc.register(const []);
    }
    // Foreground immediate apply (works even without a background-location
    // grant): are we currently inside any mosque's radius?
    final near = nearest.any((m) => m.distanceKm * 1000 <= _radiusM);
    await svc.applyNow(near);
  }
}

final mosqueSilentControllerProvider =
    NotifierProvider<MosqueSilentController, bool>(MosqueSilentController.new);
