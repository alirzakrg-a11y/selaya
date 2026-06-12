import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridges to the native Smart Silent scheduler (Android only).
///
/// The native side uses AlarmManager to fire a BroadcastReceiver at each
/// window's start (set the ringer to silent, remembering the previous mode) and
/// at its end (restore the previous mode). Needs DND / notification-policy
/// access to change the ringer on Android N+.
class SmartSilentService {
  static const MethodChannel _ch = MethodChannel('selaya/smart_silent');

  bool get _supported => Platform.isAndroid;

  /// Whether DND / notification-policy access has been granted.
  Future<bool> hasAccess() async {
    if (!_supported) return false;
    try {
      return await _ch.invokeMethod<bool>('hasAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open the system DND-access settings so the user can grant it.
  Future<void> requestAccess() async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod('requestAccess');
    } catch (_) {}
  }

  /// Schedule the silence [windows] (each a start/end epoch-ms pair). Replaces
  /// any previously scheduled windows.
  Future<void> schedule(List<({int start, int end})> windows) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod('schedule', {
        'windows': [
          for (final w in windows) {'start': w.start, 'end': w.end}
        ],
      });
    } catch (_) {}
  }

  /// Cancel all scheduled windows and restore sound if currently muted by us.
  Future<void> cancel() async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod('cancel');
    } catch (_) {}
  }
}

final smartSilentServiceProvider =
    Provider<SmartSilentService>((ref) => SmartSilentService());
