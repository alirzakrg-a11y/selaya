// Verifies finding #1's fix: prayer times honour the *city's* timezone, not the
// device's. Identical coordinates placed in two zones must differ by exactly the
// offset gap (before the fix both used the device zone and the gap was 0).
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:selaya/features/prayer_times/data/prayer_repository.dart';
import 'package:selaya/features/prayer_times/domain/prayer.dart';
import 'package:selaya/features/settings/presentation/settings_controller.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  City at(String tzName) => City(
        id: 't',
        lat: 41.0082,
        lng: 28.9784, // fixed coordinates → identical solar instants
        country: '',
        timezone: tzName,
        translations: const {},
      );

  test('prayer times follow the city timezone, not the device', () {
    const settings = AppSettings();
    final date = DateTime(2026, 6, 1);

    final istanbul = computeTimes(at('Europe/Istanbul'), settings, date); // +03
    final london = computeTimes(at('Europe/London'), settings, date); // +01 (BST)

    // Same sun → Istanbul's wall clock sits exactly 2h (the offset gap) ahead of
    // London's for every prayer.
    for (final pair in [
      [istanbul.imsak, london.imsak],
      [istanbul.dhuhr, london.dhuhr],
      [istanbul.maghrib, london.maghrib],
    ]) {
      expect(pair[0].difference(pair[1]).inMinutes, 120);
    }
  });

  test('an unresolved/empty zone falls back deterministically', () {
    const settings = AppSettings();
    final date = DateTime(2026, 6, 1);
    // Empty zone (GPS city) → device-local fallback, still stable run-to-run.
    expect(
      computeTimes(at(''), settings, date).dhuhr,
      computeTimes(at(''), settings, date).dhuhr,
    );
  });
}
