import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/data/asset_json_loader.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/calc_params.dart';
import '../domain/extended_times.dart';
import '../domain/prayer.dart';

/// All demo cities.
final citiesProvider = FutureProvider<List<City>>((ref) async {
  final loader = ref.watch(assetJsonLoaderProvider);
  return loader.loadModels('assets/data/cities.json', City.fromJson);
});

/// City resolved from settings. `cityId == 'current'` => synthetic GPS city.
final selectedCityProvider = FutureProvider<City>((ref) async {
  final cities = await ref.watch(citiesProvider.future);
  final s = ref.watch(settingsProvider);
  if (s.usesGps) {
    final name = (s.gpsName?.isNotEmpty ?? false) ? s.gpsName! : 'Konum';
    return City(
      id: 'current',
      lat: s.gpsLat!,
      lng: s.gpsLng!,
      country: '',
      timezone: '',
      translations: {
        'tr': {'name': name, 'country': 'Konumum'},
        'en': {'name': name, 'country': 'My location'},
      },
    );
  }
  return cities.firstWhere((c) => c.id == s.cityId, orElse: () => cities.first);
});

/// Manual Hijri-day correction (±days) from settings, for date formatting.
final hijriOffsetProvider = Provider<int>(
    (ref) => ref.watch(settingsProvider.select((s) => s.hijriOffsetDays)));

/// Ticks every second for live countdowns.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

/// Official online prayer times (AlAdhan; populated by `onlineTimesSyncProvider`
/// in online_times.dart), keyed by city + calendar day. [computeTimes] prefers
/// these so the displayed AND notified times match the authoritative online
/// source — the local astronomical computation is the offline fallback.
final Map<String, DailyPrayerTimes> onlinePrayerTimes = {};

String onlineTimesKey(String cityId, DateTime d) =>
    '$cityId-${d.year}-${d.month}-${d.day}';

DailyPrayerTimes computeTimes(City city, AppSettings settings, DateTime date) {
  // Prefer the official online times once fetched for this city + day.
  final cached = onlinePrayerTimes[onlineTimesKey(city.id, date)];
  if (cached != null) return cached;
  final coords = adhan.Coordinates(city.lat, city.lng);
  final params = resolveParams(
    settings.calcMethod,
    offsets: settings.offsets,
    hanafiAsr: settings.hanafiAsr,
  );
  // Pin the city's *own* UTC offset so a city in another timezone shows its real
  // local times — not the device's. Null for the GPS city (the user is there, so
  // device-local is correct) or an unresolved zone → adhan's device-local output.
  final utcOffset = _cityUtcOffset(city.timezone, date);
  final pt = adhan.PrayerTimes(
    coords,
    adhan.DateComponents.from(date),
    params,
    utcOffset: utcOffset,
  );
  // With a pinned offset, adhan returns UTC-flagged times whose wall-clock fields
  // are the city's local time; re-wrap them as naive local DateTimes so the rest
  // of the app (display, countdown, scheduling) handles them uniformly. For the
  // user's resident city (device zone == city zone) this is the exact instant.
  DateTime local(DateTime t) => utcOffset == null
      ? t
      : DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
  return DailyPrayerTimes(
    imsak: local(pt.fajr),
    sunrise: local(pt.sunrise),
    dhuhr: local(pt.dhuhr),
    asr: local(pt.asr),
    maghrib: local(pt.maghrib),
    isha: local(pt.isha),
  );
}

/// UTC offset of [tzName] on [date] (sampled at noon to dodge DST-transition
/// edges), or null when there's no zone (GPS city) or it can't be resolved — the
/// caller then keeps adhan's default device-local output.
Duration? _cityUtcOffset(String tzName, DateTime date) {
  if (tzName.isEmpty) return null;
  try {
    final loc = tz.getLocation(tzName);
    return tz.TZDateTime(loc, date.year, date.month, date.day, 12).timeZoneOffset;
  } catch (_) {
    return null;
  }
}

/// Today's times for the selected city/method.
final dailyTimesProvider = FutureProvider<DailyPrayerTimes>((ref) async {
  final city = await ref.watch(selectedCityProvider.future);
  final settings = ref.watch(settingsProvider);
  return computeTimes(city, settings, DateTime.now());
});

/// Extended/optional times (İşrak, Kuşluk, Evvabin, night thirds, Seher) + Kerahat.
final extendedTimesProvider = FutureProvider<ExtendedTimes>((ref) async {
  final city = await ref.watch(selectedCityProvider.future);
  final settings = ref.watch(settingsProvider);
  final now = DateTime.now();
  final today = computeTimes(city, settings, now);
  final tomorrow = computeTimes(city, settings, now.add(const Duration(days: 1)));
  return computeExtended(today, tomorrow.imsak);
});

/// Resolved next-prayer view (recomputed when city/method change, not per second).
final prayerViewProvider = FutureProvider<PrayerView>((ref) async {
  final city = await ref.watch(selectedCityProvider.future);
  final settings = ref.watch(settingsProvider);
  final now = DateTime.now();
  final today = computeTimes(city, settings, now);
  final ordered = today.ordered;

  final idx = ordered.indexWhere((e) => e.value.isAfter(now));
  PrayerSlot nextSlot;
  DateTime nextTime;
  DateTime prevTime;

  if (idx == -1) {
    final tomorrow = computeTimes(city, settings, now.add(const Duration(days: 1)));
    nextSlot = PrayerSlot.imsak;
    nextTime = tomorrow.imsak;
    prevTime = today.isha;
  } else if (idx == 0) {
    final yesterday =
        computeTimes(city, settings, now.subtract(const Duration(days: 1)));
    nextSlot = ordered[0].key;
    nextTime = ordered[0].value;
    prevTime = yesterday.isha;
  } else {
    nextSlot = ordered[idx].key;
    nextTime = ordered[idx].value;
    prevTime = ordered[idx - 1].value;
  }

  return PrayerView(
    city: city,
    today: today,
    nextSlot: nextSlot,
    nextTime: nextTime,
    prevTime: prevTime,
  );
});
