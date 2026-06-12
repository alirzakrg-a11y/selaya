import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/di/providers.dart';
import '../../../core/services/notification_service.dart';
import '../../calendar/data/religious_days.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/ramadan_mode.dart';

/// Two on-by-default toggles (kandil/religious days, Cuma) persisted in
/// SharedPreferences, mirroring [OngoingNotificationController]. Ramazan
/// sahur/iftar is governed by [ramadanModeProvider] instead.
abstract class NotifToggle extends Notifier<bool> {
  String get key;
  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(key) ?? true;
  Future<void> set(bool v) async {
    await ref.read(sharedPreferencesProvider).setBool(key, v);
    state = v;
  }
}

class KandilToggle extends NotifToggle {
  @override
  String get key => PrefKeys.kandilNotif;
}

class CumaToggle extends NotifToggle {
  @override
  String get key => PrefKeys.cumaNotif;
}

final kandilNotifProvider =
    NotifierProvider<KandilToggle, bool>(KandilToggle.new);
final cumaNotifProvider = NotifierProvider<CumaToggle, bool>(CumaToggle.new);

/// Schedules the "special day" notifications — kandils & religious days (reusing
/// [religiousDaysProvider]'s Hijri-derived dates), a weekly Cuma reminder, and
/// sahur/iftar during Ramadan — into a dedicated id block, refreshed on each app
/// open. Each is independently toggleable; the whole block is cancelled + rebuilt.
class SpecialNotificationScheduler {
  SpecialNotificationScheduler(this.ref);
  final Ref ref;

  Future<void> rescheduleSpecial() async {
    final notif = ref.read(notificationServiceProvider);
    await notif.init();
    await notif.cancelSpecialBlock();
    if (!await notif.isGranted()) return;

    final lang = Intl.getCurrentLocale();
    final isTr = lang == 'tr';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowTz = tz.TZDateTime.now(tz.local);
    var id = NotificationService.specialBase;

    // ── Kandils & religious days (next 60 days) ──
    if (ref.read(kandilNotifProvider)) {
      final horizon = today.add(const Duration(days: 60));
      for (final d in ref.read(religiousDaysProvider)) {
        if (id >= NotificationService.specialBase + 60) break;
        final g = d.gregorian;
        if (g.isBefore(today) || g.isAfter(horizon)) continue;
        // Kandils are night events → notify in the evening; bayrams in the
        // morning; other days mid-morning.
        final hour = d.type == 'kandil' ? 18 : (d.type == 'holiday' ? 8 : 9);
        final minute = d.type == 'kandil' ? 30 : 0;
        final when = tz.TZDateTime(tz.local, g.year, g.month, g.day, hour, minute);
        if (!when.isAfter(nowTz)) continue;
        final name = d.name(lang);
        final title = d.type == 'kandil' ? '🌙 $name' : name;
        final String body;
        if (d.type == 'kandil') {
          body = '${d.note(lang)} '
              '${isTr ? 'Kandiliniz mübarek olsun.' : 'May your night be blessed.'}';
        } else if (d.type == 'holiday') {
          body = isTr ? 'Bayramınız mübarek olsun. 🌸' : 'Eid Mubarak. 🌸';
        } else {
          body = d.note(lang);
        }
        await notif.scheduleAt(id: id++, when: when, title: title, body: body);
      }
    }

    // ── Cuma — the next 8 Fridays at 10:00 ──
    if (ref.read(cumaNotifProvider)) {
      var f = today;
      while (f.weekday != DateTime.friday) {
        f = f.add(const Duration(days: 1));
      }
      for (var i = 0; i < 8; i++) {
        final when = tz.TZDateTime(tz.local, f.year, f.month, f.day, 10, 0);
        if (when.isAfter(nowTz)) {
          await notif.scheduleAt(
            id: id++,
            when: when,
            title: isTr ? '🕌 Hayırlı Cumalar' : '🕌 Blessed Friday',
            body: isTr
                ? 'Cuma gününüz mübarek olsun. Cuma namazını ve salavâtı unutmayın.'
                : 'May your Friday be blessed — remember the Friday prayer and salawat.',
          );
        }
        f = f.add(const Duration(days: 7));
      }
    }

    // ── Ramazan — sahur (imsak) & iftar (maghrib) for Ramadan days in the next
    // 30 days. Gated by the Ramazan mode (auto/on schedule, off skips); the
    // per-date Hijri check below means nothing is scheduled outside Ramadan. ──
    if (ref.read(ramadanModeProvider) != RamadanMode.off) {
      try {
        final city = await ref.read(selectedCityProvider.future);
        final settings = ref.read(settingsProvider);
        final loc = _loc(city.timezone);
        for (var k = 0; k < 30; k++) {
          if (id >= NotificationService.specialBase + 100) break;
          final date = today.add(Duration(days: k));
          if (HijriCalendar.fromDate(date).hMonth != 9) continue; // 9 = Ramazan
          final t = computeTimes(city, settings, date);
          final sahur = tz.TZDateTime(loc, t.imsak.year, t.imsak.month,
              t.imsak.day, t.imsak.hour, t.imsak.minute);
          final iftar = tz.TZDateTime(loc, t.maghrib.year, t.maghrib.month,
              t.maghrib.day, t.maghrib.hour, t.maghrib.minute);
          if (sahur.isAfter(nowTz)) {
            await notif.scheduleAt(
              id: id++,
              when: sahur,
              title: isTr ? '🌙 Sahur vakti bitiyor' : '🌙 Suhoor ending',
              body: isTr
                  ? 'İmsak: ${_hm(t.imsak)}. Oruca niyet etmeyi unutmayın.'
                  : 'Fajr: ${_hm(t.imsak)}. Make your intention to fast.',
            );
          }
          if (iftar.isAfter(nowTz)) {
            await notif.scheduleAt(
              id: id++,
              when: iftar,
              title: isTr ? '🍽️ İftar vakti' : '🍽️ Iftar time',
              body: isTr
                  ? 'Akşam ezanı: ${_hm(t.maghrib)}. Afiyet olsun.'
                  : 'Maghrib: ${_hm(t.maghrib)}. Enjoy your iftar.',
            );
          }
        }
      } catch (_) {}
    }
  }

  tz.Location _loc(String tzName) {
    if (tzName.isNotEmpty) {
      try {
        return tz.getLocation(tzName);
      } catch (_) {}
    }
    return tz.local;
  }

  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Sample notifications, ~5 s out, so each type can be tried from Settings ──
  Future<bool> _testFire(int id, String title, String body) async {
    final notif = ref.read(notificationServiceProvider);
    await notif.init();
    if (!await notif.isGranted()) return false;
    await notif.scheduleAt(
      id: id,
      when: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      title: title,
      body: body,
    );
    return true;
  }

  bool get _isTr => Intl.getCurrentLocale() == 'tr';

  Future<bool> testKandil() => _testFire(
      9996,
      _isTr ? '🌙 Berat Kandili' : '🌙 Holy Night',
      _isTr
          ? 'Beraat ve af gecesi. Kandiliniz mübarek olsun.'
          : 'A night of forgiveness. May your night be blessed.');

  Future<bool> testCuma() => _testFire(
      9995,
      _isTr ? '🕌 Hayırlı Cumalar' : '🕌 Blessed Friday',
      _isTr
          ? 'Cuma gününüz mübarek olsun.'
          : 'May your Friday be blessed.');

  Future<bool> testIftar() => _testFire(
      9994,
      _isTr ? '🍽️ İftar vakti' : '🍽️ Iftar time',
      _isTr ? 'Akşam ezanı okundu. Afiyet olsun.' : 'Maghrib. Enjoy your iftar.');
}

final specialSchedulerProvider = Provider<SpecialNotificationScheduler>(
    (ref) => SpecialNotificationScheduler(ref));
