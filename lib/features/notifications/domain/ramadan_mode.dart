import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../core/di/providers.dart';

/// "Ramazan Modu" — governs whether the Ramadan-only behaviour is active:
/// the sahur/iftar notifications and the İmsak "sahur sona erdi" wording.
///
/// Defaults to [auto]: active exactly during the Hijri month of Ramadan
/// (month 9), so the app switches it on by itself each Ramadan and off the rest
/// of the year. The user can force it [on] (e.g. to preview) or [off].
enum RamadanMode { auto, on, off }

/// True if [d] falls inside Ramadan (Hijri month 9).
bool isRamadanDate(DateTime d) {
  try {
    return HijriCalendar.fromDate(d).hMonth == 9;
  } catch (_) {
    return false;
  }
}

class RamadanModeController extends Notifier<RamadanMode> {
  @override
  RamadanMode build() {
    final s = ref.read(sharedPreferencesProvider).getString(PrefKeys.ramadanMode);
    return RamadanMode.values.firstWhere((m) => m.name == s,
        orElse: () => RamadanMode.auto);
  }

  Future<void> set(RamadanMode m) async {
    await ref.read(sharedPreferencesProvider).setString(PrefKeys.ramadanMode, m.name);
    state = m;
  }
}

final ramadanModeProvider =
    NotifierProvider<RamadanModeController, RamadanMode>(RamadanModeController.new);

/// Resolves [ramadanModeProvider] to a plain on/off for *today* — the single
/// flag the rest of the app reads.
final ramadanActiveProvider = Provider<bool>((ref) {
  return switch (ref.watch(ramadanModeProvider)) {
    RamadanMode.on => true,
    RamadanMode.off => false,
    RamadanMode.auto => isRamadanDate(DateTime.now()),
  };
});
