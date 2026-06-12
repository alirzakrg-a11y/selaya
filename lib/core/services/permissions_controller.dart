import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/presentation/settings_controller.dart';
import 'location_service.dart';
import 'permission_service.dart';
import 'widget_service.dart';

/// Outcome of the end-to-end "use my device location" flow.
enum LocationFlowResult { saved, denied, needsSettings, noFix }

/// One snapshot of every permission/service SELAYA cares about, so any screen can
/// `watch` a single provider instead of re-checking each platform API itself.
class PermissionsState {
  final bool notifications;
  final bool exactAlarm;
  final bool location;
  final bool batteryExempt;
  final bool overlay;
  final bool fullScreenIntent;
  const PermissionsState({
    this.notifications = false,
    this.exactAlarm = false,
    this.location = false,
    this.batteryExempt = false,
    this.overlay = false,
    this.fullScreenIntent = false,
  });

  PermissionsState copyWith({
    bool? notifications,
    bool? exactAlarm,
    bool? location,
    bool? batteryExempt,
    bool? overlay,
    bool? fullScreenIntent,
  }) =>
      PermissionsState(
        notifications: notifications ?? this.notifications,
        exactAlarm: exactAlarm ?? this.exactAlarm,
        location: location ?? this.location,
        batteryExempt: batteryExempt ?? this.batteryExempt,
        overlay: overlay ?? this.overlay,
        fullScreenIntent: fullScreenIntent ?? this.fullScreenIntent,
      );
}

/// Single coordinator for everything permission/service related: notifications,
/// exact alarms, location (including the request → fix → reverse-geocode → save
/// city flow), and battery-optimization exemption.
///
/// Screens `watch` [permissionsControllerProvider] for the live status and call
/// these methods to request — no more per-screen permission plumbing or
/// divergent status checks. The low-level platform calls still live in
/// [PermissionService]/[LocationService]; this just ties them together (and
/// keeps one source of truth for the UI).
class PermissionsController extends Notifier<PermissionsState> {
  PermissionService get _perms => ref.read(permissionServiceProvider);

  @override
  PermissionsState build() {
    // Kick off an async status read; the UI updates when it lands.
    Future.microtask(refresh);
    return const PermissionsState();
  }

  /// Re-read every status at once (parallel — faster than sequential awaits).
  /// Call on app resume so a grant made in system Settings is reflected.
  Future<void> refresh() async {
    final r = await Future.wait([
      _perms.notificationsGranted(),
      _perms.exactAlarmsGranted(),
      _perms.locationGranted(),
      _perms.batteryOptimizationIgnored(),
      _perms.overlayGranted(),
      ref.read(widgetServiceProvider).canUseFullScreen(),
    ]);
    state = PermissionsState(
      notifications: r[0],
      exactAlarm: r[1],
      location: r[2],
      batteryExempt: r[3],
      overlay: r[4],
      fullScreenIntent: r[5],
    );
  }

  Future<PermissionOutcome> requestOverlay() async {
    final o = await _perms.requestOverlay();
    state = state.copyWith(overlay: o.isGranted);
    return o;
  }

  /// Android 14+ "tam ekran bildirim" özel erişimi — bu olmadan ezan alarmı
  /// kilit ekranında tam ekran açılmaz (heads-up'a düşer). Sistem ayar sayfasını
  /// açar; sonuç app resume'da [refresh] ile okunur.
  Future<void> requestFullScreenIntent() async {
    await ref.read(widgetServiceProvider).requestFullScreen();
  }

  Future<PermissionOutcome> requestNotifications() async {
    final o = await _perms.requestNotifications();
    state = state.copyWith(notifications: o.isGranted);
    // Android 14+: the full-screen adhan alarm needs a separate access.
    if (o.isGranted) {
      final ws = ref.read(widgetServiceProvider);
      if (!await ws.canUseFullScreen()) await ws.requestFullScreen();
    }
    return o;
  }

  Future<PermissionOutcome> requestExactAlarm() async {
    final o = await _perms.requestExactAlarms();
    state = state.copyWith(exactAlarm: o.isGranted);
    return o;
  }

  Future<PermissionOutcome> requestBatteryExemption() async {
    final o = await _perms.requestIgnoreBatteryOptimization();
    state = state.copyWith(batteryExempt: o.isGranted);
    return o;
  }

  /// Full device-location flow used by onboarding + the city picker: request
  /// permission, then (if granted) fetch a fix, reverse-geocode it and persist
  /// it as the active city. The [location] status flips to granted the instant
  /// permission is granted — independent of whether a fix is obtained — so the
  /// UI can reflect it immediately and never shows a stale "not granted".
  Future<LocationFlowResult> useDeviceLocation() async {
    final o = await _perms.requestLocation();
    if (o.needsSettings) return LocationFlowResult.needsSettings;
    if (!o.isGranted) return LocationFlowResult.denied;
    state = state.copyWith(location: true);
    final l = await ref.read(locationServiceProvider).currentLocation();
    if (l == null) return LocationFlowResult.noFix;
    await ref
        .read(settingsProvider.notifier)
        .setCurrentLocation(l.pos.latitude, l.pos.longitude, l.name);
    return LocationFlowResult.saved;
  }
}

final permissionsControllerProvider =
    NotifierProvider<PermissionsController, PermissionsState>(
        PermissionsController.new);
