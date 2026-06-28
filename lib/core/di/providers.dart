import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolved in `main()` and injected via [ProviderScope.overrides].
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);

/// All SharedPreferences keys in one place.
abstract final class PrefKeys {
  static const String onboardingSeen = 'onboarding_seen';
  static const String appLaunchCount =
      'app_launch_count'; // #12: 3-4. açılışta eksik izin hatırlatması
  // Üyelik (auth) — oturum token'ı + profil (json)
  static const String authToken = 'auth_token';
  static const String authUser = 'auth_user'; // json {id,name,surname,email}
  static const String deviceId =
      'device_id'; // kalıcı cihaz kimliği — en fazla 2 cihaz limiti için (senkronlanmaz)
  static const String sessionRevoked =
      'session_revoked'; // bool: oturum başka cihazda düşürüldü → bir kez bildir
  static const String bannedFlag =
      'banned_flag'; // bool: hesap banlandı → bir kez "engellendiniz" bildir
  static const String lastSyncAt = 'last_sync_at'; // int ms — son bulut senkron
  static const String themeMode = 'theme_mode';
  static const String amoled = 'amoled';
  static const String palette = 'app_palette'; // gold | green (İslami Yeşil)
  static const String recentAudio =
      'recent_audio'; // son dinlenen sesli hikâyeler (json liste)
  static const String favoriteAudio =
      'favorite_audio'; // favori sesli hikâye bölümleri (json liste)
  static const String textScale = 'text_scale'; // double: user font size (#22)
  static const String calcMethod = 'calc_method';
  static const String cityId = 'city_id';
  static const String gpsLat = 'gps_lat';
  static const String gpsLng = 'gps_lng';
  static const String gpsName = 'gps_name';
  static const String quranBookmarks = 'quran_bookmarks';
  static const String duaFavorites = 'dua_favorites'; // csv of dua ids
  static const String inspirationFavorites =
      'inspiration_favorites'; // verse/hadith favs
  static const String quranLastRead = 'quran_last_read';
  static const String quranRecentSearches = 'quran_recent_searches'; // son aramalar
  static const String dhikrTotalPrefix = 'dhikr_total_';
  static const String dhikrSound = 'dhikr_sound'; // bool
  static const String dhikrVibration =
      'dhikr_vibration'; // bool: zikir/tesbihat sayacında dokununca titreşim
  static const String dhikrSoundType = 'dhikr_sound_type'; // 'tik' | 'boncuk'
  static const String dhikrBead = 'dhikr_bead'; // int (bead color index)
  static const String dhikrCustom =
      'dhikr_custom'; // json list of custom zikirs
  static const String qiblaTheme = 'qibla_theme'; // int (compass theme index)
  static const String qiblaHaptic =
      'qibla_haptic'; // bool: vibrate on alignment
  static const String trackingPrefix =
      'tracking_'; // tracking_yyyy-MM-dd -> csv of prayer keys
  static const String trackingExtraPrefix =
      'tracking_extra_'; // +yyyy-MM-dd -> csv of quran|dhikr|sadaka
  static const String trackingAskedPrefix =
      'tracking_asked_'; // +yyyy-MM-dd -> prayers already prompted ("kıldın mı?")
  static const String checkinPrompt =
      'checkin_prompt'; // bool: vakitten sonra "namazı kıldın mı?" sorusu (default açık)
  static const String mushafLastPage =
      'mushaf_last_page'; // int: mushaf modunda kalınan sayfa (1-604)

  // Prayer fine-tuning (Round-7)
  static const String prayerOffsets =
      'prayer_offsets'; // json {slot:int minutes}
  static const String hijriOffsetDays = 'hijri_offset_days';
  static const String hanafiAsr = 'hanafi_asr';

  // Prayer notifications
  static const String prayerNotifConfig = 'prayer_notif_config'; // json
  static const String ongoingNotif =
      'ongoing_notif'; // bool: persistent next-prayer bar
  static const String dailyHadithNotif =
      'daily_hadith_notif'; // bool: daily hadith notification
  static const String dailyAyahNotif =
      'daily_ayah_notif'; // bool: daily verse notification
  static const String fullScreenAdhan =
      'full_screen_adhan'; // bool: full-screen adhan alarm enabled
  static const String notifVibration =
      'notif_vibration'; // bool: prayer notif vibration
  static const String notifLed = 'notif_led'; // bool: prayer notif LED blink
  static const String prayerAlerts =
      'prayer_alerts'; // bool: master switch for all prayer alerts
  static const String onlineTimes =
      'online_prayer_times'; // json: cached official online times
  static const String onlineTimesSyncedAt =
      'online_prayer_times_synced_at'; // epoch ms — 12 saatlik tazelik bekçisi
  static const String smartSilent =
      'smart_silent'; // bool: auto-silence during prayer & Friday
  static const String mosqueSilent =
      'mosque_silent'; // bool: auto-silence near a mosque (geofence)
  static const String kandilNotif =
      'kandil_notif'; // bool: kandil & religious-day notifications
  static const String cumaNotif = 'cuma_notif'; // bool: Friday (Cuma) reminder
  static const String ramadanMode =
      'ramadan_mode'; // string: auto|on|off — Ramazan sahur/iftar & wording

  // Women's mode
  static const String womensMode = 'womens_mode';
  static const String womensPeriods =
      'womens_periods'; // json list of {start,end}

  // Fasting tracker
  static const String fastingPrefix =
      'fasting_'; // fasting_yyyy-MM-dd -> "fasted"|"kaza"

  // Qada (kaza) prayer tracker
  static const String kazaCounts = 'kaza_counts'; // json {prayerKey:int}
  static const String kazaCompleted =
      'kaza_completed'; // int: total qada prayed
  static const String likesCache =
      'likes_cache'; // json {key:count} from server
  static const String likedKeys =
      'liked_keys'; // string list: keys the user liked
  static const String homeOrder =
      'home_order'; // string list: home section order
  static const String homeHidden =
      'home_hidden'; // string list: hidden home sections
  static const String featuredOrder =
      'featured_order'; // featured grid tool order
  static const String featuredHidden = 'featured_hidden'; // hidden grid tools

  // Daily tasks (#18) — json {yyyy-MM-dd: [completedTaskIds]}
  static const String dailyTasksLog = 'daily_tasks_log';
  static const String hatimState = 'hatim_state'; // json: aktif hatim + geçmiş
  static const String hatimReminder =
      'hatim_reminder'; // bool: hatim hatırlatması
  static const String hatimReminderHm =
      'hatim_reminder_hm'; // "HH:mm" — varsayılan 21:00

  // Özel bildirimler — gösterilmiş bildirim id'leri (string list)
  static const String seenNotificationIds = 'seen_notification_ids';
}
