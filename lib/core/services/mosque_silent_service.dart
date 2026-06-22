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

  /// Returns the FINAL on/off state — may be false even when [v] is true if a
  /// mandatory permission (location) was denied, so the UI reflects reality.
  Future<bool> setEnabled(bool v) async {
    await ref.read(sharedPreferencesProvider).setBool(PrefKeys.mosqueSilent, v);
    state = v;
    if (v) {
      await refresh(interactive: true);
    } else {
      await ref.read(mosqueSilentServiceProvider).clear();
    }
    return state;
  }

  /// Turn the toggle back off (a required permission was denied) so the switch
  /// honestly reflects that the feature can't run, and drop any geofences.
  Future<void> _revertOff() async {
    await ref.read(sharedPreferencesProvider).setBool(PrefKeys.mosqueSilent, false);
    state = false;
    await ref.read(mosqueSilentServiceProvider).clear();
  }

  /// Re-fetch nearby mosques, (re)register geofences, and apply the immediate
  /// proximity state. Called on enable and on every app resume; no-op when off.
  /// [interactive] (only on the explicit enable) may prompt for permissions.
  /// If a mandatory permission is missing it turns the toggle back off (location
  /// right away; DND on the next resume, since DND is granted from Settings).
  Future<void> refresh({bool interactive = false}) async {
    if (!state) return;
    final perm = ref.read(permissionServiceProvider);
    // 1) Foreground location is mandatory — without it we can't tell we're near
    //    a mosque. Ask on the explicit enable; if denied, turn the toggle off.
    if (!await perm.locationGranted()) {
      if (interactive) {
        final out = await perm.requestLocation();
        if (!out.isGranted) {
          await _revertOff();
          return;
        }
      } else {
        await _revertOff();
        return;
      }
    }
    // 2) DND / notification-policy is mandatory to mute the ringer (shared with
    //    the time-based Smart Silent). It's granted from a Settings screen, so
    //    on the explicit enable we open it and keep the toggle on; if the user
    //    comes back without granting, the next resume turns the toggle off.
    final silent = ref.read(smartSilentServiceProvider);
    if (!await silent.hasAccess()) {
      if (interactive) {
        await silent.requestAccess();
        return;
      }
      await _revertOff();
      return;
    }
    // 3) Optional: background location ("Allow all the time") for passive
    //    geofencing. Best effort — the foreground check works without it.
    if (interactive) await perm.requestBackgroundLocation();
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
