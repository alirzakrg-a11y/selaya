// Verifies finding #2's fix: the WMM-based magnetic declination has the right
// sign + magnitude per region (so the qibla needle gets corrected from true to
// magnetic north). Loose bounds keep it robust to WMM model-year drift.
import 'package:flutter_test/flutter_test.dart';
import 'package:selaya/core/services/declination_service.dart';
import 'package:selaya/core/utils/geo.dart';

void main() {
  test('declination sign + magnitude per region', () {
    final istanbul = magneticDeclination(const LatLng(41.0082, 28.9784));
    final newYork = magneticDeclination(const LatLng(40.7128, -74.0060));
    final mecca = magneticDeclination(const LatLng(21.4225, 39.8262));

    expect(istanbul, inInclusiveRange(3, 9)); // Türkiye: a few degrees East
    expect(newYork, inInclusiveRange(-16, -10)); // US East Coast: West
    expect(mecca, inInclusiveRange(1, 7)); // Makkah: a few degrees East
  });

  test('never throws / returns finite for an extreme location', () {
    final d = magneticDeclination(const LatLng(78.0, 15.0)); // Svalbard
    expect(d.isFinite, isTrue);
  });
}
