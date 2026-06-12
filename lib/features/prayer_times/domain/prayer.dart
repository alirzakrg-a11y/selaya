import 'package:flutter/widgets.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/geo.dart';

/// The six time slots shown in SELAYA (matches Diyanet layout).
enum PrayerSlot {
  imsak('prayer.imsak', AppIcons.imsak, true),
  sunrise('prayer.sunrise', AppIcons.sunrise, false),
  dhuhr('prayer.dhuhr', AppIcons.dhuhr, true),
  asr('prayer.asr', AppIcons.asr, true),
  maghrib('prayer.maghrib', AppIcons.maghrib, true),
  isha('prayer.isha', AppIcons.isha, true);

  const PrayerSlot(this.labelKey, this.icon, this.isPrayer);
  final String labelKey;
  final IconData icon;

  /// Whether this slot is an actual salah (excludes Sunrise) — used for tracking.
  final bool isPrayer;
}

class City {
  final String id;
  final double lat;
  final double lng;
  final String country;
  final String timezone;
  final Map<String, dynamic> translations;

  const City({
    required this.id,
    required this.lat,
    required this.lng,
    required this.country,
    required this.timezone,
    required this.translations,
  });

  LatLng get coordinates => LatLng(lat, lng);

  String name(String locale) => translations.mapFor(locale)['name'] as String;
  String countryName(String locale) =>
      translations.mapFor(locale)['country'] as String;

  factory City.fromJson(Map<String, dynamic> j) => City(
        id: j['id'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        country: j['country'] as String,
        timezone: j['timezone'] as String,
        translations: (j['translations'] as Map).cast<String, dynamic>(),
      );
}

/// A day's computed prayer times for one location.
class DailyPrayerTimes {
  final DateTime imsak;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  const DailyPrayerTimes({
    required this.imsak,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  DateTime timeOf(PrayerSlot slot) => switch (slot) {
        PrayerSlot.imsak => imsak,
        PrayerSlot.sunrise => sunrise,
        PrayerSlot.dhuhr => dhuhr,
        PrayerSlot.asr => asr,
        PrayerSlot.maghrib => maghrib,
        PrayerSlot.isha => isha,
      };

  List<MapEntry<PrayerSlot, DateTime>> get ordered =>
      [for (final s in PrayerSlot.values) MapEntry(s, timeOf(s))];

  /// The slot whose interval contains [now] (the most recent passed slot).
  PrayerSlot currentSlot(DateTime now) {
    PrayerSlot current = PrayerSlot.isha;
    for (final e in ordered) {
      if (!now.isBefore(e.value)) current = e.key;
    }
    return current;
  }
}

/// A resolved view combining today's times, the next slot and progress data.
class PrayerView {
  final City city;
  final DailyPrayerTimes today;
  final PrayerSlot nextSlot;
  final DateTime nextTime;
  final DateTime prevTime;

  const PrayerView({
    required this.city,
    required this.today,
    required this.nextSlot,
    required this.nextTime,
    required this.prevTime,
  });

  Duration remaining(DateTime now) {
    final d = nextTime.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  /// 0..1 progress through the current interval.
  double progress(DateTime now) {
    final total = nextTime.difference(prevTime).inSeconds;
    if (total <= 0) return 0;
    final passed = now.difference(prevTime).inSeconds;
    return (passed / total).clamp(0.0, 1.0);
  }

  PrayerSlot get currentSlot {
    final idx = nextSlot.index;
    return idx == 0
        ? PrayerSlot.isha
        : PrayerSlot.values[idx - 1];
  }
}
