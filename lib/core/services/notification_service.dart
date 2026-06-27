import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/notifications/domain/prayer_notification_settings.dart';
import '../../features/prayer_times/domain/prayer.dart';

/// Set to a [PrayerSlot.index] when an at-time adhan notification is tapped, the
/// full-screen intent launches the app, or the in-app watcher detects the exact
/// moment a prayer comes in. The app (SelayaApp) listens and pushes the full-screen
/// adhan alarm screen. Reset to null once consumed.
final adhanAlarmSlot = ValueNotifier<int?>(null);

/// True while the full-screen adhan alarm is on screen — guards against stacking
/// duplicate alarm routes (notification + in-app watcher can both fire).
bool adhanAlarmIsOpen = false;

void _dispatchAdhanPayload(String? payload) {
  if (payload == null || !payload.startsWith('adhan:')) return;
  final idx = int.tryParse(payload.substring('adhan:'.length));
  if (idx != null && idx >= 0 && idx < PrayerSlot.values.length) {
    adhanAlarmSlot.value = idx;
  }
}

/// Background isolate tap handler. Drives no navigation (separate isolate), but
/// MUST handle the "Durdur" action even when the app is killed: cancel the whole
/// prayer block + the test id so the adhan sound stops and the notification
/// closes (the per-action cancelNotification alone can leave a long alarm-stream
/// adhan playing on some OEMs). Also a valid entry-point so taps never crash.
@pragma('vm:entry-point')
void _onBgNotificationResponse(NotificationResponse response) {
  if (response.actionId != 'stop_adhan') return;
  final plugin = FlutterLocalNotificationsPlugin();
  for (var i = 3000; i < 3700; i++) {
    plugin.cancel(id: i);
  }
  plugin.cancel(id: 9998);
}

/// Local notifications: daily hadith (shown on the lock screen) + permission.
/// True lock-screen *widgets* aren't supported on modern Android; a public
/// notification is the platform-correct way to surface content on the lock screen.
/// ⑨ Native köprü — KAPALI (Tam Ekran OFF) at-time ezanı, durdurulabilir
/// `AdhanPlayerService` (MediaPlayer) ile çalmak için.
const _adhanNativeChannel = MethodChannel('selaya/widget');

class NotificationService {
  NotificationService(this._plugin);
  final FlutterLocalNotificationsPlugin _plugin;
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {}
    // Do NOT auto-request permission on init — iOS only ever prompts once, and
    // consuming that prompt at startup is exactly why the explicit "Grant"
    // button later appeared to do nothing. Permission is requested on demand
    // through PermissionService instead.
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (r) {
        // "Durdur" tapped while the app is alive → stop every sounding prayer
        // notification (closes it + cuts the adhan); otherwise route the adhan.
        if (r.actionId == 'stop_adhan') {
          cancelActivePrayerSounds();
        } else {
          _dispatchAdhanPayload(r.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: _onBgNotificationResponse,
    );
    await _createPrayerChannels();
    // If the app was launched by tapping (or the full-screen intent of) an
    // at-time adhan notification, surface the alarm once we're up.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _dispatchAdhanPayload(launch!.notificationResponse?.payload);
      }
    } catch (_) {}
    _inited = true;
  }

  static const int ongoingId = 2000;
  static const String _ongoingChannel = 'selaya_ongoing';
  static const String _specialChannel = 'selaya_special';
  static const int specialBase = 5000;

  /// One Android channel per [AdhanSound] (sounds are immutable per-channel) +
  /// a silent low-importance channel for the persistent "next prayer" notice.
  Future<void> _createPrayerChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    // One-time cleanup: drop older channel versions (pre-_v2 placeholders, _v2,
    // and the _v3/_v3s alarm-stream experiments) so Settings doesn't show stale
    // duplicates and the new profile-respecting channels take effect.
    final combo = '${prayerVibration ? 1 : 0}';
    for (final s in AdhanSound.values) {
      for (final old in [
        'selaya_prayer_${s.id}',
        'selaya_prayer_${s.id}_v2',
        'selaya_prayer_${s.id}_v3',
        'selaya_prayer_${s.id}_v3s',
        'selaya_prayer_${s.id}_v4',
        'selaya_prayer_${s.id}_alarm_v1',
        // Eski 2-haneli titreşim+LED kombolar (LED kaldırıldı) — hepsini sil.
        for (final v in const ['00', '01', '10', '11']) ...[
          'selaya_prayer_${s.id}_v5_$v',
          'selaya_prayer_${s.id}_alarm_v2_$v',
        ],
        // Güncel 1-haneli (sadece titreşim) kombo DIŞINDakini sil.
        for (final v in const ['0', '1'])
          if (v != combo) ...[
            'selaya_prayer_${s.id}_v5_$v',
            'selaya_prayer_${s.id}_alarm_v2_$v',
          ],
      ]) {
        try {
          await android.deleteNotificationChannel(channelId: old);
        } catch (_) {}
      }
    }
    for (final s in AdhanSound.values) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          s.channelId,
          'Namaz — ${s.id}',
          description: 'Namaz vakti bildirimi (${s.id})',
          importance: Importance.max,
          playSound: !s.isSilent,
          sound: s.androidRaw == null
              ? null
              : RawResourceAndroidNotificationSound(s.androidRaw!),
          enableVibration: prayerVibration,
          // NOTIFICATION stream → the adhan follows the phone's ringer profile
          // (sound normal / vibrate / quiet). Titreşim kullanıcı ayarından.
          audioAttributesUsage: AudioAttributesUsage.notification,
        ),
      );
    }
    // At-time adhan channels on the ALARM stream so the adhan sounds at prayer
    // time even on silent/vibrate and even while Smart Silent has muted the
    // ringer (alarms are exempt from ringer mode). Before-reminders use the
    // notification-stream channels created above.
    for (final s in AdhanSound.values) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          s.alarmChannelId,
          'Namaz vakti — ${s.id}',
          description: 'Vakit girince çalan ezan (${s.id})',
          importance: Importance.max,
          playSound: !s.isSilent,
          sound: s.androidRaw == null
              ? null
              : RawResourceAndroidNotificationSound(s.androidRaw!),
          enableVibration: prayerVibration,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
    }
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _ongoingChannel,
        'Sıradaki Vakit',
        description: 'Durum çubuğunda sürekli görünen sıradaki namaz vakti',
        importance: Importance.low,
        playSound: false,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _specialChannel,
        'Özel Günler',
        description: 'Kandil, Cuma, Ramazan ve dini gün bildirimleri',
        importance: Importance.high,
      ),
    );
  }

  /// Persistent, non-dismissible "next prayer" notification (Android only).
  ///
  /// Collapsed: [subText] (city) in the header + [collapsedTitle]/[collapsedBody]
  /// with a live system countdown. Expanded (pull-down): [expandedTitle] over
  /// [expandedBody] — all of today's times in a bold 2×3 grid plus a short
  /// hadith. [expandedBody]/[expandedTitle] are HTML (so `<b>` bolds and `<br>`
  /// breaks lines — Android collapses `\n`). [nextTime] drives the chronometer.
  Future<void> showOngoingPrayer({
    required String? subText,
    required String collapsedTitle,
    required String collapsedBody,
    required String expandedTitle,
    required String expandedBody,
    required tz.TZDateTime nextTime,
  }) async {
    if (!Platform.isAndroid) return;
    await init();
    final android = AndroidNotificationDetails(
      _ongoingChannel,
      'Sıradaki Vakit',
      channelDescription:
          'Durum çubuğunda sürekli görünen sıradaki namaz vakti',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      showWhen: true,
      when: nextTime.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      subText: subText,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.status,
      styleInformation: BigTextStyleInformation(
        expandedBody,
        htmlFormatBigText: true,
        contentTitle: expandedTitle,
        htmlFormatContentTitle: true,
        summaryText: subText,
      ),
    );
    await _plugin.show(
      id: ongoingId,
      title: collapsedTitle,
      body: collapsedBody,
      notificationDetails: NotificationDetails(android: android),
    );
  }

  Future<void> cancelOngoing() async {
    await init();
    try {
      await _plugin.cancel(id: ongoingId);
    } catch (_) {}
  }

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  Future<bool> requestPermission() async {
    await init();
    if (Platform.isIOS) {
      final pre = await _ios?.checkPermissions();
      if (pre?.isEnabled ?? false) return true;
      return await _ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> isGranted() async {
    if (Platform.isIOS) {
      await init();
      final s = await _ios?.checkPermissions();
      return s?.isEnabled ?? false;
    }
    return Permission.notification.isGranted;
  }

  /// Android 12+ exact-alarm permission. Returns false if unavailable/denied.
  Future<bool> requestExactAlarms() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true; // iOS doesn't need it
    final ok = await android.requestExactAlarmsPermission();
    return ok ?? false;
  }

  NotificationDetails _details(String body) => NotificationDetails(
    android: AndroidNotificationDetails(
      'selaya_hadith',
      'Günün Hadisi',
      channelDescription: 'Günlük hadis-i şerif bildirimi',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.public, // show on lock screen
      styleInformation: BigTextStyleInformation(body),
    ),
    iOS: const DarwinNotificationDetails(),
  );

  Future<void> showHadithNow({
    required String title,
    required String text,
    required String reference,
  }) async {
    await init();
    final body = '$text\n\n— $reference';
    await _plugin.show(
      id: 1001,
      title: title,
      body: body,
      notificationDetails: _details(body),
    );
  }

  /// Yönetim panelinden gönderilen duyuru/özel bildirim için ayrı kanal.
  NotificationDetails _announceDetails(String body) => NotificationDetails(
    android: AndroidNotificationDetails(
      'selaya_announce',
      'SELAYA Duyurular',
      channelDescription: 'Uygulama duyuruları ve özel bildirimler',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(body),
    ),
    iOS: const DarwinNotificationDetails(),
  );

  /// Panelden gönderilen özel/yönetici bildirimini gösterir.
  Future<void> showCustom({
    required int id,
    required String title,
    String? body,
  }) async {
    await init();
    final b = (body == null || body.isEmpty) ? title : body;
    await _plugin.show(
      id: id,
      title: title,
      body: b,
      notificationDetails: _announceDetails(b),
    );
  }

  static const int hadithDailyId = 1002;
  static const int ayahDailyId = 1003;
  static const int hatimReminderId = 1004;

  /// Schedules a daily repeating notification at [hour]:[minute] local time.
  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _details(body),
        // Exact so Doze / Samsung battery optimization doesn't defer or drop the
        // daily verse & hadith (USE_EXACT_ALARM is declared). Inexact fallback if
        // exact alarms aren't permitted on this device.
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: _details(body),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {}
    }
  }

  /// Daily repeating hadith notification (default 09:00).
  Future<void> scheduleDailyHadith({
    int hour = 9,
    int minute = 0,
    required String title,
    required String text,
    required String reference,
  }) => _scheduleDaily(
    id: hadithDailyId,
    hour: hour,
    minute: minute,
    title: title,
    body: '$text\n\n— $reference',
  );

  /// Daily repeating verse-of-the-day notification (default 08:00).
  Future<void> scheduleDailyAyah({
    int hour = 8,
    int minute = 0,
    required String title,
    required String text,
    required String reference,
  }) => _scheduleDaily(
    id: ayahDailyId,
    hour: hour,
    minute: minute,
    title: title,
    body: '$text\n\n— $reference',
  );

  Future<void> cancelDailyHadith() => cancelIds([hadithDailyId]);
  Future<void> cancelDailyAyah() => cancelIds([ayahDailyId]);

  /// Hatim hatırlatması (günlük tekrar). [skipToday]=true ise ilk tetik yarın
  /// (o gün hedef zaten tamamlandıysa bugünü atla). Aynı `_scheduleDaily`
  /// deseni; bağımsız id (1004) ile diğer günlük bildirimleri etkilemez.
  Future<void> scheduleHatimReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    bool skipToday = false,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (skipToday || !when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    try {
      await _plugin.zonedSchedule(
        id: hatimReminderId,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _details(body),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id: hatimReminderId,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: _details(body),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {}
    }
  }

  Future<void> cancelHatimReminder() => cancelIds([hatimReminderId]);

  /// One-shot dated notification on the "Özel Günler" channel — used for kandil
  /// / religious-day, Cuma and Ramazan (sahur/iftar) reminders. Exact if
  /// permitted, inexact fallback otherwise; a no-op if [when] is already past.
  Future<void> scheduleAt({
    required int id,
    required tz.TZDateTime when,
    required String title,
    required String body,
  }) async {
    await init();
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _specialChannel,
        'Özel Günler',
        channelDescription: 'Kandil, Cuma, Ramazan ve dini gün bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(),
    );
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {}
    }
  }

  /// Özel (kullanıcı tanımlı) hatırlatıcı — verilen saatte gösterilir; [daily]
  /// ise her gün tekrarlar. Id'ler [customReminderBase] bloğundan gelir; vakit/
  /// özel bildirimlerle çakışmaz. (kullanıcı 2026-06-17)
  static const int customReminderBase = 7000;
  Future<void> scheduleCustomReminder({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required bool daily,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    final match = daily ? DateTimeComponents.time : null;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _details(body),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: match,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: _details(body),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: match,
        );
      } catch (_) {}
    }
  }

  Future<void> cancelCustomReminder(int id) => cancelIds([id]);

  /// Clears the whole special-notification id block [specialBase, +100).
  Future<void> cancelSpecialBlock() =>
      cancelIds([for (int i = specialBase; i < specialBase + 100; i++) i]);

  NotificationDetails _prayerDetails(
    AdhanSound sound,
    String body, {
    bool fullScreen = false,
    bool atTime = false,
    bool dropSound = false,
    bool mute = false,
    String? stopLabel,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      // [mute] → sessiz "görsel" kanal: ezan sesi native serviste çalarken
      // bu bildirim yalnız tam-ekran alarmı tetikler (çift ses olmasın).
      // At-time → alarm-stream channel (the adhan sounds even on
      // silent/vibrate); before-reminders → notification-stream channel.
      mute
          ? 'selaya_adhan_visual'
          : (atTime ? sound.alarmChannelId : sound.channelId),
      mute ? 'Ezan — tam ekran' : 'Namaz — ${sound.id}',
      channelDescription: 'Namaz vakti bildirimi',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      // "Tam Ekran Alarm" — when on, wake the screen and show the full-screen
      // adhan alarm over the lock screen; off → a plain heads-up that rings.
      fullScreenIntent: fullScreen,
      // Full-screen ON: must NOT auto-cancel — the full-screen launch (or a
      // tap) would dismiss the notification, and dismissing a sounding
      // notification STOPS its sound, cutting the adhan as the app opens. Kept
      // alive, the alarm-channel adhan plays as a fallback; "Durdur" stops it.
      // Full-screen OFF: there's no adhan screen, so the notification IS the
      // adhan — tapping it should close it + stop the sound, like an alarm.
      // (mute'ta ses bildirimde değil → kapatmak sesi etkilemez, autoCancel OK.)
      autoCancel: mute || !(atTime && fullScreen),
      playSound: !mute && sound != AdhanSound.silent,
      // [dropSound] omits the raw-resource sound: a resilience fallback for
      // when the resource can't be resolved (so scheduling still succeeds and
      // the channel's own sound is used) — a missing sound must never again
      // silently stop the whole prayer notification from being scheduled.
      sound: (mute || dropSound || sound.androidRaw == null)
          ? null
          : RawResourceAndroidNotificationSound(sound.androidRaw!),
      // "Durdur" action — tapping it cancels the notification (which stops the
      // adhan) WITHOUT opening the app, exactly like an alarm's stop button.
      actions: (atTime && stopLabel != null)
          ? <AndroidNotificationAction>[
              AndroidNotificationAction(
                'stop_adhan',
                stopLabel,
                cancelNotification: true,
                showsUserInterface: false,
              ),
            ]
          : null,
      styleInformation: BigTextStyleInformation(body),
    ),
    iOS: DarwinNotificationDetails(
      presentSound: sound != AdhanSound.silent,
      sound: sound.iosFile,
      // Time-sensitive at prayer time (breaks Focus) but still respects the
      // hardware silent switch. A plain reminder is "active".
      interruptionLevel: atTime
          ? InterruptionLevel.timeSensitive
          : InterruptionLevel.active,
    ),
  );

  /// Schedule a single prayer notification at [when] (exact if permitted). For
  /// the at-time adhan, pass [stopLabel] (the "Durdur" action) and — when the
  /// "Tam Ekran Alarm" is on — [alarmSlot], which adds the full-screen intent +
  /// an `adhan:<index>` payload so the full-screen adhan alarm opens.
  Future<void> schedulePrayer({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required AdhanSound sound,
    PrayerSlot? alarmSlot,
    bool atTime = false,
    String? stopLabel,
  }) async {
    await init();
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    // ⑨ At-time ezan HER ZAMAN native serviste çalar (AdhanPlayerService —
    // MediaPlayer, alarm-muafiyetli AlarmManager): "Durdur" sesi GERÇEKTEN keser
    // ve uygulama ölüyken bile çalar. Tam Ekran KAPALI → native bildirimi tek
    // deneyimdir (burada biter). Tam Ekran AÇIK → ses yine native'te; aşağıda
    // yalnız SESSİZ bir tam-ekran tetik bildirimi kurulur (eskiden kanal sesi +
    // 15 sn sonra tam ekran = ÇİFT ezan saçmalığı vardı). Native kurulamazsa
    // eski kanal-sesi yoluna düşülür → ezan ASLA susmaz.
    var nativeAdhan = false;
    // At-time ezan native AdhanPlayerService'te (MediaPlayer) çalar → "Kapat" sesi
    // ANINDA keser. (Kanal-sesi yolu Samsung'da DURDURULAMIYOR — bildirimi
    // kapatınca sistem RingtonePlayer ezanı çalmaya devam ediyor; kullanıcı
    // şikâyeti buydu.) FGS tipi artık shortService: Android 14+'ın arka-plan
    // exact-alarm'dan başlatmaya İZİN VERDİĞİ tip (mediaPlayback YASAKTI — ezanı
    // sessizce düşüren oydu) ve Play tanıtım-videosu gerektirmez. Tam Ekran KAPALI
    // (varsayılan) → bu native bildirim tek deneyimdir (erken return). Native
    // KURULAMAZSA (catch) aşağıdaki kanal-sesi yoluna düşülür → ezan en azından çalar.
    if (atTime && sound != AdhanSound.silent && sound.androidRaw != null) {
      try {
        await _adhanNativeChannel.invokeMethod('scheduleAdhanAlarm', {
          'id': id,
          'time': when.millisecondsSinceEpoch,
          'res': sound.androidRaw,
          'label': title,
        });
        nativeAdhan = true;
        if (alarmSlot == null) return;
      } catch (_) {
        /* native başarısız → kanal-sesi yoluna düş */
      }
    }
    // The adhan plays from the alarm-stream channel (sounds even on
    // silent/vibrate) — unless the native service owns the sound (then this
    // notification is the MUTED full-screen trigger only). With [alarmSlot] it
    // wakes the full-screen alarm.
    final details = _prayerDetails(
      sound,
      body,
      fullScreen: alarmSlot != null,
      atTime: atTime,
      mute: nativeAdhan,
      stopLabel: stopLabel,
    );
    final payload = alarmSlot == null ? null : 'adhan:${alarmSlot.index}';
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // Exact alarms not permitted → fall back to an inexact alarm.
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (_) {
        // Last resort: schedule WITHOUT the custom sound so the alert still fires
        // (the channel's own sound/default is used). A bad sound resource must
        // never stop the prayer notification from being scheduled at all.
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: when,
            notificationDetails: _prayerDetails(
              sound,
              body,
              fullScreen: alarmSlot != null,
              atTime: atTime,
              mute: nativeAdhan,
              stopLabel: stopLabel,
              dropSound: true,
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: payload,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> cancelIds(Iterable<int> ids) async {
    await init();
    for (final id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (_) {}
    }
  }

  /// Cancels any *currently-showing* at-time prayer notification (the prayer id
  /// block 3000–3699 + the at-time test id 9998) so its alarm-channel adhan
  /// stops — called when the full-screen adhan screen takes over and plays the
  /// adhan itself, so the two never double. Only affects already-posted
  /// notifications (getActiveNotifications); scheduled ones are untouched.
  Future<void> cancelActivePrayerSounds() async {
    // ⑨ Native ezan servisi çalıyorsa onu da durdur (Durdur her yerden çalışsın).
    try {
      await _adhanNativeChannel.invokeMethod('stopAdhan');
    } catch (_) {}
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    try {
      final active = await android.getActiveNotifications();
      for (final n in active) {
        final id = n.id;
        if (id == null) continue;
        if ((id >= 3000 && id < 3700) || id == 9998) {
          await _plugin.cancel(id: id);
        }
      }
    } catch (_) {}
  }

  /// Yalnızca native ezan-sesi alarmı kurar (görsel bildirim OLMADAN) — görsel
  /// pencerenin ötesindeki günler için. Native taraf 50'lik kayan pencereyle
  /// AlarmManager'a takar; ezan, uygulama haftalarca açılmasa da çalar.
  Future<void> scheduleNativeAdhan({
    required tz.TZDateTime when,
    required AdhanSound sound,
    required String label,
  }) async {
    if (sound == AdhanSound.silent || sound.androidRaw == null) return;
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    try {
      await _adhanNativeChannel.invokeMethod('scheduleAdhanAlarm', {
        'id': 0,
        'time': when.millisecondsSinceEpoch,
        'res': sound.androidRaw,
        'label': label,
      });
    } catch (_) {
      /* native yoksa görsel pencere yine de korur */
    }
  }

  /// ⑨ Kayıtlı native ezan alarmlarını (AlarmManager) iptal et + listeyi temizle.
  /// `rescheduleAll` başında çağrılır: eski alarmlar temizlenir, döngü yenilerini
  /// `schedulePrayer` üzerinden tekrar kurar.
  Future<void> cancelNativeAdhanAlarms() async {
    try {
      await _adhanNativeChannel.invokeMethod('cancelAllAdhanAlarms');
    } catch (_) {}
  }
}

/// Single shared plugin instance (FlutterLocalNotificationsPlugin is itself a
/// singleton, but exposing it as a provider lets PermissionService and the
/// scheduler talk to the exact same instance explicitly).
final localNotificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>(
      (ref) => FlutterLocalNotificationsPlugin(),
    );

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.read(localNotificationsPluginProvider)),
);
