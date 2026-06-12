import 'package:geomag/geomag.dart';

import '../utils/geo.dart';

/// Magnetic declination in degrees (+East) at [at] for [date] (now if null),
/// from the bundled World Magnetic Model.
///
/// Compass sensors report heading from *magnetic* north, while the qibla bearing
/// is computed from *true* north — so the qibla needle is off by this angle
/// (≈+6° in Türkiye, but up to ~±15° elsewhere) unless corrected. Isolated here
/// (like `qibla_sensor_service`) so the geomag dependency stays swappable.
double magneticDeclination(LatLng at, [DateTime? date]) {
  try {
    return GeoMag().calculate(at.latitude, at.longitude, 0, date).dec;
  } catch (_) {
    return 0; // never break the compass over a model failure
  }
}
