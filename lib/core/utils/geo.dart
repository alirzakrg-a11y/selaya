import 'dart:math' as math;

/// Simple lat/lng pair (decoupled from any plugin types).
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

/// The Kaaba, Makkah.
const LatLng kaaba = LatLng(21.4225, 39.8262);

double _deg2rad(double d) => d * math.pi / 180.0;
double _rad2deg(double r) => r * 180.0 / math.pi;

/// Initial great-circle bearing (degrees from true north) from [from] to the Kaaba.
double qiblaBearing(LatLng from) {
  final lat1 = _deg2rad(from.latitude);
  final lat2 = _deg2rad(kaaba.latitude);
  final dLon = _deg2rad(kaaba.longitude - from.longitude);
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (_rad2deg(math.atan2(y, x)) + 360.0) % 360.0;
}

/// Haversine distance in kilometres.
double distanceKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = _deg2rad(b.latitude - a.latitude);
  final dLon = _deg2rad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(a.latitude)) *
          math.cos(_deg2rad(b.latitude)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Güneşin konumu: gerçek kuzeye göre saat yönünde azimut (0..360) ve ufuk
/// üstü yüksekliği (derece; <0 = ufkun altında). Yaklaşık (güneşi kıble
/// referansı olarak kullanmaya yetecek doğrulukta).
class SunPosition {
  final double azimuth; // gerçek kuzeyden saat yönünde
  final double altitude; // ufkun üstü (derece); negatifse battı
  const SunPosition(this.azimuth, this.altitude);
}

SunPosition sunPosition(LatLng at, DateTime whenUtc) {
  final n = whenUtc.difference(DateTime.utc(2000, 1, 1, 12)).inMilliseconds /
      86400000.0; // J2000.0'dan beri gün
  final lDeg = (280.460 + 0.9856474 * n) % 360; // ortalama boylam
  final gRad = _deg2rad((357.528 + 0.9856003 * n) % 360); // ortalama anomali
  final lambda = _deg2rad(
      (lDeg + 1.915 * math.sin(gRad) + 0.020 * math.sin(2 * gRad)) % 360);
  final eps = _deg2rad(23.439 - 0.0000004 * n); // eğiklik
  final delta = math.asin(math.sin(eps) * math.sin(lambda)); // dik açıklık
  final alpha =
      math.atan2(math.cos(eps) * math.sin(lambda), math.cos(lambda)); // RA
  final gmstHours = (18.697374558 + 24.06570982441908 * n) % 24;
  final lstRad = _deg2rad(((gmstHours * 15) + at.longitude) % 360);
  final h = lstRad - alpha; // saat açısı
  final latRad = _deg2rad(at.latitude);
  final alt = math.asin(math.sin(latRad) * math.sin(delta) +
      math.cos(latRad) * math.cos(delta) * math.cos(h));
  var az = math.atan2(math.sin(h),
      math.cos(h) * math.sin(latRad) - math.tan(delta) * math.cos(latRad));
  az = (_rad2deg(az) + 180) % 360;
  if (az < 0) az += 360;
  return SunPosition(az, _rad2deg(alt));
}

/// Pusula/ibre animasyonu için: hedef tur değerini ([target]; tam tur = 1.0)
/// birikmiş [current] değerine en yakın eş değere taşır; fark daima ±0.5 tur
/// içinde kalır. Böylece AnimatedRotation 0/360 (0/1 tur) sınırında uzun
/// yoldan (ters) dönmez, hep en kısa yoldan döner.
double shortestTurns(double current, double target) {
  var diff = (target - current) % 1.0;
  if (diff > 0.5) diff -= 1.0;
  return current + diff;
}

/// 16-point compass label key (for "Southeast" etc.). Returns an i18n key.
String compassDirectionKey(double bearing) {
  // Only the qibla screen needs SE for Turkey demo; keep it simple.
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final idx = ((bearing + 22.5) % 360 ~/ 45);
  return dirs[idx];
}
