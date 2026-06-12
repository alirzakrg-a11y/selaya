import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pushes data to the native Android home-screen widgets via a MethodChannel
/// (self-contained bridge — no third-party widget plugin). One [update] call
/// writes every key and refreshes all SELAYA widgets; each provider reads its own.
class WidgetService {
  const WidgetService();

  static const _channel = MethodChannel('selaya/widget');

  /// Writes all [data] keys into the shared widget store and refreshes widgets.
  Future<void> update(Map<String, String> data) async {
    try {
      await _channel.invokeMethod<void>('update', data);
    } catch (_) {
      // No widget added / not Android — safe to ignore.
    }
  }

  Future<void> updateHadith({
    required String text,
    required String reference,
    required String label,
  }) =>
      update({'text': text, 'ref': reference, 'label': label});

  /// Returns + clears the `adhan:<slot>` payload stashed by the native side when
  /// an at-time adhan notification (full-screen intent) launched/resumed the app.
  /// Null when there's nothing pending.
  Future<String?> getPendingAdhan() async {
    try {
      return await _channel.invokeMethod<String>('getPendingAdhan');
    } catch (_) {
      return null;
    }
  }

  /// Whether the app may show a full-screen adhan alarm (Android 14+ gates it).
  Future<bool> canUseFullScreen() async {
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreen') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the Android 14+ "full screen notifications" special-access screen.
  Future<void> requestFullScreen() async {
    try {
      await _channel.invokeMethod<void>('requestFullScreen');
    } catch (_) {}
  }
}

final widgetServiceProvider = Provider<WidgetService>((ref) => const WidgetService());
