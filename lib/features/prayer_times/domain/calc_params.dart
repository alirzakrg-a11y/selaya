import 'package:adhan/adhan.dart' as adhan;

import '../../settings/presentation/settings_controller.dart';
import 'prayer.dart';

/// Resolves a [CalcMethod] into fully-configured adhan [CalculationParameters],
/// applying the user's Asr madhab and per-prayer minute [offsets].
///
/// Native adhan methods use `.getParameters()` (which also sets the built-in
/// `methodAdjustments`); regional methods adhan doesn't ship use
/// `CalculationMethod.other` with explicit Fajr/Isha angles. The user [offsets]
/// are written to `adjustments` (separate from `methodAdjustments`) so they add
/// on top of the method's own corrections.
adhan.CalculationParameters resolveParams(
  CalcMethod method, {
  Map<PrayerSlot, int> offsets = const {},
  bool hanafiAsr = false,
}) {
  final params = _base(method);
  params.madhab = hanafiAsr ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
  params.adjustments = adhan.PrayerAdjustments(
    fajr: offsets[PrayerSlot.imsak] ?? 0,
    sunrise: offsets[PrayerSlot.sunrise] ?? 0,
    dhuhr: offsets[PrayerSlot.dhuhr] ?? 0,
    asr: offsets[PrayerSlot.asr] ?? 0,
    maghrib: offsets[PrayerSlot.maghrib] ?? 0,
    isha: offsets[PrayerSlot.isha] ?? 0,
  );
  return params;
}

adhan.CalculationParameters _custom(double fajr, double isha) =>
    adhan.CalculationParameters(
      method: adhan.CalculationMethod.other,
      fajrAngle: fajr,
      ishaAngle: isha,
    );

adhan.CalculationParameters _base(CalcMethod m) => switch (m) {
      // Native adhan methods
      CalcMethod.diyanet => adhan.CalculationMethod.turkey.getParameters(),
      CalcMethod.mwl =>
        adhan.CalculationMethod.muslim_world_league.getParameters(),
      CalcMethod.egypt => adhan.CalculationMethod.egyptian.getParameters(),
      CalcMethod.karachi => adhan.CalculationMethod.karachi.getParameters(),
      CalcMethod.ummAlQura => adhan.CalculationMethod.umm_al_qura.getParameters(),
      CalcMethod.dubai => adhan.CalculationMethod.dubai.getParameters(),
      CalcMethod.moonsighting =>
        adhan.CalculationMethod.moon_sighting_committee.getParameters(),
      CalcMethod.northAmerica =>
        adhan.CalculationMethod.north_america.getParameters(),
      CalcMethod.kuwait => adhan.CalculationMethod.kuwait.getParameters(),
      CalcMethod.qatar => adhan.CalculationMethod.qatar.getParameters(),
      CalcMethod.singapore => adhan.CalculationMethod.singapore.getParameters(),
      CalcMethod.tehran => adhan.CalculationMethod.tehran.getParameters(),
      // Regional methods via custom Fajr/Isha angles
      CalcMethod.jafari => _custom(16.0, 14.0),
      CalcMethod.franceUOIF => _custom(12.0, 12.0),
      CalcMethod.russia => _custom(16.0, 15.0),
      CalcMethod.morocco => _custom(19.0, 17.0),
      CalcMethod.indonesia => _custom(20.0, 18.0),
      CalcMethod.tunisia => _custom(18.0, 18.0),
    };
