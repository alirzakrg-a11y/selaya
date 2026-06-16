import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/services/notification_service.dart';
import '../../../core/services/ongoing_prayer_service.dart';
import '../../../core/services/smart_silent_service.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/ramadan_mode.dart';
import 'prayer_notification_controller.dart';
import 'reminder_quotes.dart';

/// Schedules prayer notifications for a rolling window of [_days] days.
///
/// IDs occupy a fixed block so the whole set can be cancelled and rebuilt on
/// any config/city/method/offset change, or on the daily roll.
class PrayerScheduler {
  PrayerScheduler(this.ref);
  final Ref ref;

  static const int _base = 3000;
  static const int _days = 7;

  /// Ezan SESİ (native alarm) bu kadar gün ileriye kurulur: uygulama hiç
  /// açılmasa bile native taraf kayan pencereyle (her ezan/BOOT'ta ileri kayar)
  /// bir ay boyunca ezanı garanti eder. Görsel bildirimler [_days] gün.
  static const int _nativeDays = 30;

  /// IDs occupy [_base, _base + _days*100). `kind` 0 = at-time, 1..N = the Nth
  /// "before" reminder for that slot.
  int _id(int day, PrayerSlot slot, int kind) =>
      _base + day * 100 + slot.index * 8 + kind;

  Future<void> cancelAll() async {
    final notif = ref.read(notificationServiceProvider);
    await notif.cancelIds([for (int i = _base; i < _base + _days * 100; i++) i]);
    await notif.cancelNativeAdhanAlarms(); // ⑨ native ezan alarmlarını da temizle
  }

  /// "🕌 Ezan (vakit)" test. Fires the at-time adhan ~5 s out — a heads-up that
  /// rings the **selected imam's** adhan on the alarm channel with a "Durdur"
  /// action. (The full-screen alarm has its own [testFullScreenAlarm].) Returns
  /// false only if notifications aren't granted.
  Future<bool> testAtTime() async {
    final notif = ref.read(notificationServiceProvider);
    await notif.init();
    if (!await notif.isGranted()) return false;
    final sound =
        ref.read(prayerNotificationProvider).alarmFor(PrayerSlot.imsak).atTimeSound;
    await notif.schedulePrayer(
      id: 9998,
      title: '${PrayerSlot.imsak.labelKey.tr()} • ${_hm(DateTime.now())}',
      body: 'notif.testBody'.tr(),
      when: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      sound: sound,
      atTime: true,
      stopLabel: 'notif.adhanStop'.tr(),
    );
    return true;
  }

  /// "📱 Tam Ekran Alarm" test — schedules a REAL full-screen-intent adhan alarm
  /// [seconds] out (default 10) so the user can LOCK the screen first and see it
  /// pop over the lock screen. Scheduling the actual notification (with the
  /// full-screen intent + adhan payload) is the only way to exercise the
  /// locked-screen path — an in-app open wouldn't. False if not granted.
  Future<bool> testFullScreenAlarm({int seconds = 10}) async {
    final notif = ref.read(notificationServiceProvider);
    await notif.init();
    if (!await notif.isGranted()) return false;
    final sound = ref
        .read(prayerNotificationProvider)
        .alarmFor(PrayerSlot.imsak)
        .atTimeSound;
    await notif.schedulePrayer(
      id: 9998,
      title: '${PrayerSlot.imsak.labelKey.tr()} • ${_hm(DateTime.now())}',
      body: 'notif.testBody'.tr(),
      when: tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
      sound: sound,
      atTime: true,
      stopLabel: 'notif.adhanStop'.tr(),
      alarmSlot: null, // tam ekran ezan KALDIRILDI — ses native serviste çalar
    );
    return true;
  }

  /// Fires a sample BEFORE-reminder ~5 s out (gentle chime + a verse) — how the
  /// "30/10 dk kala" reminders arrive.
  Future<bool> testBefore() async {
    final notif = ref.read(notificationServiceProvider);
    await notif.init();
    if (!await notif.isGranted()) return false;
    final sound =
        ref.read(prayerNotificationProvider).alarmFor(PrayerSlot.imsak).beforeSound;
    await notif.schedulePrayer(
      id: 9997,
      title: 'notif.beforeTitle'.tr(args: [PrayerSlot.imsak.labelKey.tr(), '10']),
      body: ReminderQuotes.random(Intl.getCurrentLocale()),
      when: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      sound: sound,
    );
    return true;
  }

  /// Cancel and rebuild the rolling window. No-op (after cancel) if the user
  /// hasn't granted notification permission.
  Future<void> rescheduleAll() async {
    final notif = ref.read(notificationServiceProvider);
    await notif.init();
    await cancelAll();
    if (!await notif.isGranted()) {
      await ref.read(ongoingPrayerServiceProvider).stop();
      await notif.cancelOngoing();
      return;
    }

    final config = ref.read(prayerNotificationProvider);
    final fullScreen = ref.read(fullScreenAdhanProvider);
    final ramadan = ref.read(ramadanActiveProvider);
    final settings = ref.read(settingsProvider);
    final city = await ref.read(selectedCityProvider.future);
    final loc = _locationFor(city);
    final lang = Intl.getCurrentLocale();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Master switch: when off, schedule NO prayer alerts at all (the persistent
    // status + Smart Silent below keep their own toggles).
    final alertsOn = ref.read(prayerAlertsProvider);
    for (var day = 0; alertsOn && day < _days; day++) {
      final date = today.add(Duration(days: day));
      final times = computeTimes(city, settings, date);
      for (final slot in PrayerSlot.values) {
        final alarm = config.alarmFor(slot);
        if (!alarm.anyEnabled) continue;
        final name = slot.labelKey.tr();
        final t = times.timeOf(slot);

        if (alarm.atTime) {
          // At-time → the adhan rings on the alarm stream (even on silent/vibrate,
          // even while Smart Silent muted the ringer). "Tam Ekran Alarm" on → also
          // opens the full-screen adhan alarm; the "Durdur" action/button stops it
          // either way.
          await notif.schedulePrayer(
            id: _id(day, slot, 0),
            title: '$name • ${_hm(t)}',
            body: _atTimeBody(slot, name, ramadan),
            when: _tz(t, loc),
            sound: alarm.atTimeSound,
            atTime: true,
            stopLabel: 'notif.adhanStop'.tr(),
            alarmSlot: fullScreen ? slot : null,
          );
        }
        if (alarm.beforeEnabled) {
          // One notification per "minutes before" reminder (e.g. 30 and 10).
          // Title (bold): "Güneş ezanına 30 dk kaldı"; body: a random verse/hadith.
          for (var i = 0; i < alarm.beforeOffsets.length && i < 7; i++) {
            final m = alarm.beforeOffsets[i];
            await notif.schedulePrayer(
              id: _id(day, slot, 1 + i),
              title: 'notif.beforeTitle'.tr(args: [name, '$m']),
              body: ReminderQuotes.random(lang),
              when: _tz(t.subtract(Duration(minutes: m)), loc),
              sound: alarm.beforeSound,
            );
          }
        }
      }
    }

    // ⏳ SÜRESİZLİK GARANTİSİ: görsel pencerenin ötesindeki günler için yalnız
    // native ezan-sesi alarmı kur (30 güne kadar). Native taraf ilk 50'sini
    // AlarmManager'a takar, kalanını saklar ve pencereyi kendi kaydırır →
    // kullanıcı uygulamayı haftalarca açmasa da ezan susmaz.
    for (var day = _days; alertsOn && day < _nativeDays; day++) {
      final date = today.add(Duration(days: day));
      final times = computeTimes(city, settings, date);
      for (final slot in PrayerSlot.values) {
        final alarm = config.alarmFor(slot);
        if (!alarm.anyEnabled || !alarm.atTime) continue;
        final t = times.timeOf(slot);
        await notif.scheduleNativeAdhan(
          when: _tz(t, loc),
          sound: alarm.atTimeSound,
          label: '${slot.labelKey.tr()} • ${_hm(t)}',
        );
      }
    }

    await _updateOngoing(notif, settings, city);
    await _updateSmartSilent(settings, city);
  }

  /// Smart Silent (#6.2): schedule native silence windows around each fard
  /// prayer (with a longer Friday/Jumu'ah window) for the rolling window, or
  /// cancel them when the feature is off. Native mutes only if DND access is
  /// granted; the ringer is restored at each window's end.
  Future<void> _updateSmartSilent(AppSettings settings, City city) async {
    final svc = ref.read(smartSilentServiceProvider);
    if (!settings.smartSilent) {
      await svc.cancel();
      return;
    }
    final loc = _locationFor(city);
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final today = DateTime(now.year, now.month, now.day);
    const fard = [
      PrayerSlot.imsak,
      PrayerSlot.dhuhr,
      PrayerSlot.asr,
      PrayerSlot.maghrib,
      PrayerSlot.isha,
    ];
    final windows = <({int start, int end})>[];
    for (var day = 0; day < _days; day++) {
      final date = today.add(Duration(days: day));
      final times = computeTimes(city, settings, date);
      for (final slot in fard) {
        final startMs = _tz(times.timeOf(slot), loc).millisecondsSinceEpoch;
        final friday =
            date.weekday == DateTime.friday && slot == PrayerSlot.dhuhr;
        final endMs = startMs + (friday ? 50 : 15) * 60 * 1000;
        if (endMs <= nowMs) continue; // skip windows already in the past
        windows.add((start: startMs, end: endMs));
      }
    }
    await svc.schedule(windows);
  }

  /// Starts/refreshes (or stops) the native foreground service that owns the
  /// persistent "next prayer" notification. The service re-posts notification
  /// 2000 every minute so the worded "🕌 X vaktine kalan : N dk" body ticks down
  /// live even when the app is killed (the system chronometer already ticks
  /// per-second on its own). Android-only; a no-op elsewhere via the service's
  /// platform guard.
  Future<void> _updateOngoing(
      NotificationService notif, AppSettings settings, City city) async {
    final ongoing = ref.read(ongoingPrayerServiceProvider);
    if (!ref.read(ongoingNotificationProvider)) {
      await ongoing.stop();
      await notif.cancelOngoing();
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final loc = _locationFor(city);

    // Full rolling-window list (names + absolute epoch ms) so the native service
    // can advance to the next prayer across days without the app being open.
    final names = <String>[];
    final timesMs = <int>[];
    for (var day = 0; day < _days; day++) {
      final date = today.add(Duration(days: day));
      final times = computeTimes(city, settings, date);
      for (final slot in PrayerSlot.values) {
        names.add(slot.labelKey.tr());
        timesMs.add(_tz(times.timeOf(slot), loc).millisecondsSinceEpoch);
      }
    }

    // Today's six "HH:mm" for the expanded 2×3 grid.
    final todayTimes = computeTimes(city, settings, today);
    final gridHm = [for (final s in PrayerSlot.values) _hm(todayTimes.timeOf(s))];

    final lang = Intl.getCurrentLocale();
    final isTr = lang == 'tr';
    await ongoing.start(
      location: city.name(lang),
      names: names,
      timesMs: timesMs,
      gridHm: gridHm,
      // "{} vaktine kalan" with the placeholder kept intact; the native side
      // substitutes the next prayer's name as it advances (word order is
      // locale-correct because the whole phrase comes from the translation).
      template: 'notif.ongoingCountdown'.tr(args: ['{}']),
      hourUnit: isTr ? 'saat' : 'hr',
      minUnit: isTr ? 'dk' : 'min',
      icon: '🕌',
    );
  }

  /// At-time body, named per slot: "Akşam namazı vakti geldi", or the special
  /// İmsak/Güneş wording (these aren't a salah). The İmsak body only mentions
  /// "sahur sona erdi" when [ramadan] (Ramazan modu) is active — otherwise it's
  /// just the plain İmsak wording, so a sahur message never shows off-season.
  static String _atTimeBody(PrayerSlot slot, String name, bool ramadan) {
    switch (slot) {
      case PrayerSlot.imsak:
        return ramadan
            ? 'notif.atTimeImsak'.tr()
            : 'notif.atTimeImsakPlain'.tr();
      case PrayerSlot.sunrise:
        return 'notif.atTimeSunrise'.tr();
      default:
        return 'notif.atTimeNamed'.tr(args: [name]);
    }
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// The city's own zone (falling back to the device zone for the GPS city or an
  /// unresolved zone) so notifications fire at the city's local time — matching
  /// the displayed times even when browsing/living in another timezone.
  tz.Location _locationFor(City city) {
    if (city.timezone.isNotEmpty) {
      try {
        return tz.getLocation(city.timezone);
      } catch (_) {}
    }
    return tz.local;
  }

  tz.TZDateTime _tz(DateTime t, tz.Location loc) =>
      tz.TZDateTime(loc, t.year, t.month, t.day, t.hour, t.minute);
}

final prayerSchedulerProvider =
    Provider<PrayerScheduler>((ref) => PrayerScheduler(ref));
