import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';
import '../../notifications/data/prayer_scheduler.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/prayer.dart';
import 'prayer_repository.dart';

/// Maps the app's [CalcMethod] to the matching AlAdhan API `method` id.
/// Diyanet (Turkey) = 13 — the default and the important one for Turkish users.
int _aladhanMethod(CalcMethod m) => switch (m) {
      CalcMethod.diyanet => 13,
      CalcMethod.mwl => 3,
      CalcMethod.egypt => 5,
      CalcMethod.karachi => 1,
      CalcMethod.ummAlQura => 4,
      CalcMethod.dubai => 16,
      CalcMethod.moonsighting => 15,
      CalcMethod.northAmerica => 2,
      CalcMethod.kuwait => 9,
      CalcMethod.qatar => 10,
      CalcMethod.singapore => 11,
      CalcMethod.tehran => 7,
      CalcMethod.jafari => 0,
      CalcMethod.franceUOIF => 12,
      CalcMethod.russia => 14,
      CalcMethod.morocco => 21,
      CalcMethod.indonesia => 20,
      CalcMethod.tunisia => 18,
    };

DateTime? _parse(DateTime day, Object? hhmm) {
  if (hhmm is! String) return null;
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(hhmm);
  if (m == null) return null;
  return DateTime(day.year, day.month, day.day, int.parse(m[1]!), int.parse(m[2]!));
}

/// Fetches one calendar month of official times from AlAdhan for [city] and
/// writes them into [onlinePrayerTimes]. İmsak ← Fajr (the Diyanet morning
/// time). Returns true if at least one day was stored.
Future<bool> _fetchMonth(City city, CalcMethod method, int year, int month) async {
  final url = Uri.https('api.aladhan.com', '/v1/calendar/$year/$month', {
    'latitude': '${city.lat}',
    'longitude': '${city.lng}',
    'method': '${_aladhanMethod(method)}',
  });
  try {
    final res = await http.get(url).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return false;
    final list = (jsonDecode(res.body) as Map)['data'] as List;
    var any = false;
    for (final e in list) {
      final t = (e as Map)['timings'] as Map;
      final day = DateTime(year, month,
          int.parse(((e['date'] as Map)['gregorian'] as Map)['day'] as String));
      final imsak = _parse(day, t['Fajr']);
      final sunrise = _parse(day, t['Sunrise']);
      final dhuhr = _parse(day, t['Dhuhr']);
      final asr = _parse(day, t['Asr']);
      final maghrib = _parse(day, t['Maghrib']);
      final isha = _parse(day, t['Isha']);
      if (imsak == null ||
          sunrise == null ||
          dhuhr == null ||
          asr == null ||
          maghrib == null ||
          isha == null) {
        continue;
      }
      onlinePrayerTimes[onlineTimesKey(city.id, day)] = DailyPrayerTimes(
        imsak: imsak,
        sunrise: sunrise,
        dhuhr: dhuhr,
        asr: asr,
        maghrib: maghrib,
        isha: isha,
      );
      any = true;
    }
    return any;
  } catch (_) {
    return false;
  }
}

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

Future<void> _saveCache(SharedPreferences prefs) async {
  // 35 günden eski girişleri buda — önbellek yıllarca şişmesin.
  final cutoff = DateTime.now().subtract(const Duration(days: 35));
  final m = <String, String>{};
  onlinePrayerTimes.forEach((k, v) {
    if (v.imsak.isBefore(cutoff)) return;
    m[k] =
        '${_hm(v.imsak)},${_hm(v.sunrise)},${_hm(v.dhuhr)},${_hm(v.asr)},${_hm(v.maghrib)},${_hm(v.isha)}';
  });
  await prefs.setString(PrefKeys.onlineTimes, jsonEncode(m));
}

void _loadCache(SharedPreferences prefs) {
  final raw = prefs.getString(PrefKeys.onlineTimes);
  if (raw == null) return;
  try {
    (jsonDecode(raw) as Map).forEach((key, val) {
      final p = (key as String).split('-');
      final times = (val as String).split(',');
      if (p.length < 4 || times.length != 6) return;
      final y = int.parse(p[p.length - 3]);
      final mo = int.parse(p[p.length - 2]);
      final d = int.parse(p[p.length - 1]);
      DateTime at(int i) {
        final hm = times[i].split(':');
        return DateTime(y, mo, d, int.parse(hm[0]), int.parse(hm[1]));
      }
      onlinePrayerTimes[key] = DailyPrayerTimes(
        imsak: at(0),
        sunrise: at(1),
        dhuhr: at(2),
        asr: at(3),
        maghrib: at(4),
        isha: at(5),
      );
    });
  } catch (_) {}
}

Future<void> _refresh(Ref ref) async {
  ref.invalidate(dailyTimesProvider);
  ref.invalidate(extendedTimesProvider);
  ref.invalidate(prayerViewProvider);
  await ref.read(prayerSchedulerProvider).rescheduleAll();
}

/// Fetches the official online prayer times (AlAdhan, method per the user's calc
/// method) for the selected city — current + next month — so the İmsak and all
/// vakit are authoritative + current. Persisted to prefs for offline use; the
/// local astronomical computation is the fallback. Re-runs on city/method change
/// VE her uygulama dönüşünde (app.dart resume → invalidate); içerideki tazelik
/// bekçisi sayesinde ağa en fazla 12 saatte bir çıkar — kapsama hep ileride
/// kalır, "2 ay sonra ne olacak?" diye bir son tarih YOKTUR.
final onlineTimesSyncProvider = FutureProvider<void>((ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final city = await ref.watch(selectedCityProvider.future);
  final method = ref.watch(settingsProvider.select((s) => s.calcMethod));

  // Show the last-saved online times instantly (offline-friendly).
  if (onlinePrayerTimes.isEmpty) {
    _loadCache(prefs);
    if (onlinePrayerTimes.isNotEmpty) await _refresh(ref);
  }

  // TAZELİK BEKÇİSİ: son eşitleme 12 saatten yeniyse VE önümüzdeki 14 gün
  // eksiksiz kapsanıyorsa ağa çıkma (resume'daki invalidate'ler bedava olur).
  // Ay sınırına yaklaşınca kapsama 14 günün altına düşer → otomatik yeni ay
  // çekilir; süresiz tazelik böyle sağlanır.
  final now = DateTime.now();
  final lastSync = prefs.getInt(PrefKeys.onlineTimesSyncedAt) ?? 0;
  final fresh =
      now.millisecondsSinceEpoch - lastSync < const Duration(hours: 12).inMilliseconds;
  var covered = true;
  for (var d = 0; d < 14; d++) {
    final day = now.add(Duration(days: d));
    if (!onlinePrayerTimes.containsKey(onlineTimesKey(city.id, day))) {
      covered = false;
      break;
    }
  }
  if (fresh && covered) return;

  // Then refresh from the network (best-effort).
  final next = DateTime(now.year, now.month + 1, 1);
  final a = await _fetchMonth(city, method, now.year, now.month);
  final b = await _fetchMonth(city, method, next.year, next.month);
  if (a || b) {
    await prefs.setInt(
        PrefKeys.onlineTimesSyncedAt, now.millisecondsSinceEpoch);
    await _saveCache(prefs);
    await _refresh(ref);
  }
});
