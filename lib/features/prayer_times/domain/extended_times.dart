import 'prayer.dart';

/// A named extended/optional time — either a single moment ([end] == null) or a
/// window ([start]..[end]). Labels are i18n keys.
class ExtTime {
  final String labelKey;
  final DateTime start;
  final DateTime? end;
  const ExtTime(this.labelKey, this.start, [this.end]);

  /// A window with non-positive duration is degenerate (high-latitude collapse).
  bool get isValid => end == null || end!.isAfter(start);
}

/// Derived "extra" prayer times (İşrak, Kuşluk, Evvabin, night thirds, Seher)
/// and the three Kerahat (forbidden) windows — all pure functions of the six
/// canonical times plus tomorrow's Fajr.
class ExtendedTimes {
  final List<ExtTime> segments;
  final List<ExtTime> kerahat;
  const ExtendedTimes({required this.segments, required this.kerahat});
}

/// [t] today's times, [nextFajr] tomorrow's Fajr (for night-third / Seher math).
ExtendedTimes computeExtended(DailyPrayerTimes t, DateTime nextFajr) {
  const afterSunrise = Duration(minutes: 45); // İşrak / Kerahat-1 length
  final israk = t.sunrise.add(afterSunrise);
  final duhaEnd = t.dhuhr.subtract(const Duration(minutes: 30));

  final nightSecs = nextFajr.difference(t.maghrib).inSeconds;
  final third = Duration(seconds: nightSecs ~/ 3);
  final n1 = t.maghrib.add(third);
  final n2 = t.maghrib.add(third * 2);
  final seherStart = nextFajr.subtract(Duration(seconds: nightSecs ~/ 6));

  return ExtendedTimes(
    segments: [
      ExtTime('prayer.israk', israk),
      ExtTime('prayer.duha', israk, duhaEnd),
      ExtTime('prayer.evvabin', t.maghrib, t.isha),
      ExtTime('prayer.night1', t.maghrib, n1),
      ExtTime('prayer.night2', n1, n2),
      ExtTime('prayer.night3', n2, nextFajr),
      ExtTime('prayer.seher', seherStart, nextFajr),
    ],
    kerahat: [
      ExtTime('prayer.kerahatSunrise', t.sunrise, israk),
      ExtTime('prayer.kerahatZenith',
          t.dhuhr.subtract(const Duration(minutes: 15)), t.dhuhr),
      ExtTime('prayer.kerahatSunset',
          t.maghrib.subtract(const Duration(minutes: 40)), t.maghrib),
    ],
  );
}
