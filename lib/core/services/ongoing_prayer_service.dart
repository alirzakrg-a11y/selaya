import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridges to the native `OngoingNotif` helper, which posts the persistent
/// "next prayer" notification (id 2000) — the worded "🕌 X vaktine kalan : H:MM:SS"
/// body counts down live (system chronometer) even when the app is killed, and a
/// single self-chaining exact alarm advances it to the next prayer. NO foreground
/// service (the old specialUse FGS was dropped for Play compliance). Android-only;
/// a no-op elsewhere.
class OngoingPrayerService {
  static const _channel = MethodChannel('selaya/ongoing');

  /// Starts (or refreshes) the persistent countdown notification with the
  /// rolling-window prayer data. [names]/[timesMs] are parallel lists for the
  /// full window (the native side picks the next prayer whose time is still in
  /// the future); [gridHm] is
  /// today's six pre-formatted "HH:mm" values for the expanded grid. [template]
  /// is the localized "{} vaktine kalan" string (the `{}` is replaced natively
  /// with the next prayer's name as it advances).
  Future<void> start({
    required String location,
    required List<String> names,
    required List<int> timesMs,
    required List<String> gridHm,
    required String template,
    required String hourUnit,
    required String minUnit,
    required String icon,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('start', {
        'location': location,
        'names': names,
        'times': timesMs,
        'gridHm': gridHm,
        'template': template,
        'hourUnit': hourUnit,
        'minUnit': minUnit,
        'icon': icon,
      });
    } catch (_) {}
  }

  /// Removes notification 2000 and cancels the advance alarm.
  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}

final ongoingPrayerServiceProvider =
    Provider<OngoingPrayerService>((ref) => OngoingPrayerService());
