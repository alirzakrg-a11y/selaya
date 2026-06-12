import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';
import '../../womens_mode/data/womens_mode_controller.dart';
import '../domain/fasting_day.dart';

/// Thin SharedPreferences-backed store for fasting days
/// (`fasting_yyyy-MM-dd` -> "fasted" | "kaza").
class FastingStore {
  FastingStore(this._prefs);
  final SharedPreferences _prefs;

  String _key(DateTime d) =>
      '${PrefKeys.fastingPrefix}${d.toIso8601String().substring(0, 10)}';

  FastStatus statusFor(DateTime d) =>
      FastStatus.fromId(_prefs.getString(_key(d)));

  Future<void> setStatus(DateTime d, FastStatus s) async {
    if (s == FastStatus.none) {
      await _prefs.remove(_key(d));
    } else {
      await _prefs.setString(_key(d), s.id!);
    }
  }

  /// All-time count of days with the given status.
  int totalWith(FastStatus s) {
    var n = 0;
    for (final k in _prefs.getKeys()) {
      if (k.startsWith(PrefKeys.fastingPrefix) && _prefs.getString(k) == s.id) {
        n++;
      }
    }
    return n;
  }

  /// Count within a Gregorian month.
  int countInMonth(int year, int month, FastStatus s) {
    final days = DateTime(year, month + 1, 0).day;
    var n = 0;
    for (var d = 1; d <= days; d++) {
      if (statusFor(DateTime(year, month, d)) == s) n++;
    }
    return n;
  }

  /// Consecutive fasted days ending today; women's-mode days are skipped
  /// (neutral, don't break the streak).
  int streak(WomensMode wm) {
    var streak = 0;
    var day = DateTime.now();
    for (var i = 0; i < 400; i++) {
      if (wm.isExcluded(day)) {
        day = day.subtract(const Duration(days: 1));
        continue;
      }
      if (statusFor(day) == FastStatus.fasted) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}

final fastingStoreProvider =
    Provider<FastingStore>((ref) => FastingStore(ref.read(sharedPreferencesProvider)));
