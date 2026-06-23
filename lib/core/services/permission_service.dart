import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notification_service.dart';

/// Result of a permission request, shared across iOS + Android so the UI can
/// react uniformly: grant succeeded, was denied (can ask again), or the OS will
/// no longer prompt and the user must enable it from system Settings.
enum PermissionOutcome { granted, denied, needsSettings }

extension PermissionOutcomeX on PermissionOutcome {
  bool get isGranted => this == PermissionOutcome.granted;
  bool get needsSettings => this == PermissionOutcome.needsSettings;
}

/// One permission API for both platforms (notifications, exact alarms,
/// location). iOS notification permission goes through the flutter_local_-
/// notifications iOS plugin (the same `UNUserNotificationCenter` that actually
/// delivers our notifications); everything else goes through permission_handler
/// / geolocator. A denial that the OS won't re-prompt is surfaced as
/// [PermissionOutcome.needsSettings] so callers can deep-link to Settings.
class PermissionService {
  PermissionService(this._plugin);
  final FlutterLocalNotificationsPlugin _plugin;

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  // ---------------------------------------------------------------- notifications
  Future<bool> notificationsGranted() async {
    if (Platform.isIOS) {
      final s = await _ios?.checkPermissions();
      return s?.isEnabled ?? false;
    }
    return Permission.notification.isGranted;
  }

  Future<PermissionOutcome> requestNotifications() async {
    if (Platform.isIOS) {
      // If already authorised, don't re-request (iOS only prompts once).
      final pre = await _ios?.checkPermissions();
      if (pre?.isEnabled ?? false) return PermissionOutcome.granted;
      final ok = await _ios?.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
      if (ok) return PermissionOutcome.granted;
      // iOS returns false both for a fresh denial and for "already decided".
      // Either way the system dialog won't show again → send them to Settings.
      final post = await _ios?.checkPermissions();
      if (post?.isEnabled ?? false) return PermissionOutcome.granted;
      return PermissionOutcome.needsSettings;
    }
    final status = await Permission.notification.request();
    if (status.isGranted) return PermissionOutcome.granted;
    if (status.isPermanentlyDenied) return PermissionOutcome.needsSettings;
    return PermissionOutcome.denied;
  }

  // ----------------------------------------------------------------- exact alarms
  /// Android 12+ needs a separate user grant to fire exact alarms. iOS has no
  /// equivalent, so it's always "granted" there.
  Future<bool> exactAlarmsGranted() async {
    if (!Platform.isAndroid) return true;
    return Permission.scheduleExactAlarm.isGranted;
  }

  Future<PermissionOutcome> requestExactAlarms() async {
    if (!Platform.isAndroid) return PermissionOutcome.granted;
    final ok = await _android?.requestExactAlarmsPermission() ?? false;
    if (ok) return PermissionOutcome.granted;
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) return PermissionOutcome.granted;
    if (status.isPermanentlyDenied) return PermissionOutcome.needsSettings;
    return PermissionOutcome.denied;
  }

  // ------------------------------------------------------- battery optimization
  /// Android only: whether SELAYA is exempt from battery optimization (Doze).
  /// When it is NOT exempt, the OS can defer or drop our scheduled exact alarms
  /// while the app is backgrounded — so prayer/adhan alerts arrive late or never.
  /// iOS has no equivalent, so it always reports "ignored".
  Future<bool> batteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Shows the system "allow SELAYA to ignore battery optimization?" dialog.
  /// (Backed by REQUEST_IGNORE_BATTERY_OPTIMIZATIONS; justified for a prayer
  /// alarm app.) On iOS this is a no-op that reports granted.
  Future<PermissionOutcome> requestIgnoreBatteryOptimization() async {
    if (!Platform.isAndroid) return PermissionOutcome.granted;
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isGranted) return PermissionOutcome.granted;
    if (status.isPermanentlyDenied) return PermissionOutcome.needsSettings;
    return PermissionOutcome.denied;
  }

  // --------------------------------------------------------------------- overlay
  /// Android "draw over other apps" (SYSTEM_ALERT_WINDOW). Lets the full-screen
  /// adhan alarm launch over other apps / from the background reliably (an OEM
  /// background-activity-start exemption). iOS has no equivalent → always true.
  Future<bool> overlayGranted() async {
    if (!Platform.isAndroid) return true;
    return Permission.systemAlertWindow.isGranted;
  }

  Future<PermissionOutcome> requestOverlay() async {
    if (!Platform.isAndroid) return PermissionOutcome.granted;
    final status = await Permission.systemAlertWindow.request();
    if (status.isGranted) return PermissionOutcome.granted;
    if (status.isPermanentlyDenied) return PermissionOutcome.needsSettings;
    return PermissionOutcome.denied;
  }

  // -------------------------------------------------------------------- location
  Future<bool> locationGranted() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always ||
        p == LocationPermission.whileInUse;
  }

  /// Requests location, returning [PermissionOutcome.needsSettings] when the
  /// location *service* is off or the permission was permanently denied.
  Future<PermissionOutcome> requestLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return PermissionOutcome.needsSettings;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.always ||
        p == LocationPermission.whileInUse) {
      return PermissionOutcome.granted;
    }
    if (p == LocationPermission.deniedForever) {
      return PermissionOutcome.needsSettings;
    }
    return PermissionOutcome.denied;
  }

  /// Opens the OS app-settings page (used when an outcome is [needsSettings]).
  Future<bool> openSettings() => openAppSettings();
}

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionService(ref.read(localNotificationsPluginProvider)),
);
