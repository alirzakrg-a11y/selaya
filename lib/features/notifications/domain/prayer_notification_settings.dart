import 'dart:convert';

import '../../prayer_times/domain/prayer.dart';

/// A notification sound: silence, the system default, or one of eight named
/// muezzins. Each maps to a dedicated Android channel (sounds are immutable
/// per-channel), an iOS bundle file, and an in-app preview asset. The muezzin
/// files are real ~10-24s adhan recordings under assets/audio/adhan + res/raw.
/// Bildirim titreşimi ve LED'i — kullanıcı ayarından (açılışta yüklenir,
/// değişince kanallar yeniden oluşturulur). Kanal id'sine yansır ki Android
/// yeni ayarı alsın (kanal özellikleri oluşturulduktan SONRA değişmez → yeni
/// id = taze kanal).
bool prayerVibration = true;

enum AdhanSound {
  silent(id: 'silent', labelKey: 'notif.soundSilent'),
  defaultTone(id: 'default', labelKey: 'notif.soundDefault'),
  // Soft, ~5s glockenspiel chime — the default for "before" reminders: gentle
  // yet noticeable, long enough not to vanish instantly (see res/raw/notif_chime).
  chime(id: 'chime', labelKey: 'notif.soundChime', file: 'notif_chime'),
  // TELİF TEMİZLİĞİ (2026-06-11, Play Store hazırlığı): kaynağı kanıtlanamayan
  // 7 isimli klip (mishary, ahmed_nafees, hafiz_mustafa, masjid_haram,
  // qari_kareem, sheikh_jamac, salah_mansor) + ticari albümden çıktığı ID3 ile
  // kanıtlanan karl_jenkins KALDIRILDI. Yalnız belgeli/lisanslı kayıtlar
  // dağıtılır; eski seçimler fromId() ile meccaFull'a taşınır.
  // Freely-licensed adhan from Wikimedia Commons (reciter Aaqib Azeez, uploaded
  // by Atcovi, CC BY-SA 4.0). Shown like the other muezzins by the reciter's
  // name; the formal attribution is registered in main.dart (LicenseRegistry)
  // and documented in NOTICE_AUDIO.md.
  aaqibAzeez(id: 'commons', properName: 'Aaqib Azeez', file: 'adhan_commons'),
  // TAM (kesintisiz) ezanlar — diğer kayıtlar ~10-24 sn'lik klipti ("ezan bir
  // anda kesiliyor" şikâyetinin kökü). İkisi de Wikimedia Commons'tan, gerçek
  // cami kayıtları; atıflar main.dart LicenseRegistry + NOTICE_AUDIO.md'de.
  // (iOS .caf karşılıkları henüz paketlenmedi — Android öncelikli.)
  meccaFull(
      id: 'mecca_full',
      properName: 'Mescid-i Harâm · Tam Ezan (3:17)',
      file: 'adhan_mecca_full'),
  meccaMaghrib(
      id: 'mecca_maghrib',
      properName: 'Mescid-i Harâm · Akşam Ezanı (5:01)',
      file: 'adhan_mecca_maghrib'),
  hassan2Full(
      id: 'hassan2_full',
      properName: 'Hassan II Camii · Tam Ezan (2:55)',
      file: 'adhan_hassan2_full'),
  // KISA (≤25 sn) YASAL ezanlar — Public Domain / CC0 gerçek kayıtlar.
  // Mescid-i Harâm (Mekke) — CC0 (Internet Archive), gerçek ~25 sn kayıt.
  makkah(
      id: 'makkah',
      properName: 'Mescid-i Harâm · Kısa Ezan (0:25)',
      file: 'adhan_makkah'),
  // Abdunnâsır Harak (Mısır) — Public Domain (Internet Archive), 24 sn.
  harak(
      id: 'harak',
      properName: 'Abdunnâsır Harak · Mısır (0:24)',
      file: 'adhan_harak'),
  // Sabah Fahri (efsanevi Suriyeli ses sanatçısı) — PUBLIC DOMAIN, yüksek
  // kaliteli (stereo) 24 sn kısa ezan; Wikimedia Commons.
  fakhri(
      id: 'fakhri',
      properName: 'Sabah Fahri · Kısa Ezan (0:24)',
      file: 'adhan_fakhri');

  const AdhanSound({required this.id, this.labelKey, this.properName, this.file});

  final String id;

  /// i18n key for silence/default (null for muezzins, which use [properName]).
  final String? labelKey;

  /// Proper name for a muezzin (null for silence/default).
  final String? properName;

  /// Base filename for the adhan recording — Android `res/raw/<file>.mp3`, the
  /// in-app preview asset `assets/audio/adhan/<file>.mp3`. Null for silence/default.
  final String? file;

  String? get androidRaw => file;
  // iOS notification sounds must be CAF/WAV/AIFF (MP3 is not supported) and
  // bundled in the app — see ios/Runner/Sounds/*.caf.
  String? get iosFile => file == null ? null : '$file.caf';
  String? get assetPath => file == null ? null : 'assets/audio/adhan/$file.mp3';

  /// Android notification channel id bound to this sound. Plays on the
  /// NOTIFICATION stream so the adhan follows the phone's ringer profile (sound
  /// in normal, vibrate in vibrate, quiet in silent). The version suffix forces
  /// a fresh channel because the audio attributes are immutable once created
  /// (`_v4` replaced the earlier ALARM-stream `_v3`).
  String get channelId =>
      'selaya_prayer_${id}_v5_${prayerVibration ? 1 : 0}';

  /// Alarm-stream channel for the **at-time adhan**. Unlike [channelId]
  /// (notification stream), the alarm stream is exempt from ringer mode — so the
  /// adhan sounds at prayer time even on silent/vibrate, and even while Smart
  /// Silent has muted the ringer. Before-reminders keep the gentler [channelId].
  String get alarmChannelId =>
      'selaya_prayer_${id}_alarm_v2_${prayerVibration ? 1 : 0}';

  bool get isCustom => file != null;
  bool get isSilent => this == AdhanSound.silent;

  static AdhanSound fromId(String id) {
    // Telif temizliğinde kaldırılan eski müezzin id'leri → ezan kaybolmasın
    // diye tam Mekke ezanına taşınır (defaultTone sistem sesi olurdu).
    const legacyAdhans = {
      'ahmed_nafees', 'mishary', 'hafiz_mustafa', 'masjid_haram',
      'qari_kareem', 'sheikh_jamac', 'karl_jenkins', 'salah_mansor',
    };
    if (legacyAdhans.contains(id)) return AdhanSound.meccaFull;
    return AdhanSound.values.firstWhere((s) => s.id == id,
        orElse: () => AdhanSound.defaultTone);
  }

  /// Named adhan voices (assets/audio/adhan + res/raw). TAM ezanlar başta —
  /// kullanıcı kesintisiz ezan istiyor; kısa klipler (~10-24 sn) sonda kalır.
  static const muezzins = [
    meccaFull,
    meccaMaghrib,
    hassan2Full,
    aaqibAzeez,
    // KISA (≤25 sn) YASAL ezanlar (PD/CC0) — sonda.
    fakhri,
    makkah,
    harak,
  ];
}

/// Per-prayer alarm configuration: an at-time alert and zero or more
/// before-time reminders (e.g. 20 and 10 minutes prior), each with its own
/// sound — mirroring the PDF's "Vakit Zamanında" / "Vakitlerden Önce" sections.
class PrayerAlarm {
  final bool atTime;
  final AdhanSound atTimeSound;
  final bool beforeEnabled;
  final List<int> beforeOffsets; // minutes before the prayer, e.g. [20, 10]
  final AdhanSound beforeSound;

  const PrayerAlarm({
    this.atTime = false,
    this.atTimeSound = AdhanSound.defaultTone,
    this.beforeEnabled = false,
    this.beforeOffsets = const [15],
    this.beforeSound = AdhanSound.defaultTone,
  });

  bool get anyEnabled => atTime || (beforeEnabled && beforeOffsets.isNotEmpty);

  PrayerAlarm copyWith({
    bool? atTime,
    AdhanSound? atTimeSound,
    bool? beforeEnabled,
    List<int>? beforeOffsets,
    AdhanSound? beforeSound,
  }) =>
      PrayerAlarm(
        atTime: atTime ?? this.atTime,
        atTimeSound: atTimeSound ?? this.atTimeSound,
        beforeEnabled: beforeEnabled ?? this.beforeEnabled,
        beforeOffsets: beforeOffsets ?? this.beforeOffsets,
        beforeSound: beforeSound ?? this.beforeSound,
      );

  Map<String, dynamic> toJson() => {
        'atTime': atTime,
        'atSound': atTimeSound.id,
        'before': beforeEnabled,
        'offsets': beforeOffsets,
        'beforeSound': beforeSound.id,
      };

  factory PrayerAlarm.fromJson(Map<String, dynamic> j) {
    // Back-compat with the old single-offset / single-sound shape.
    final legacySound = AdhanSound.fromId(j['sound'] as String? ?? 'default');
    final offsets = (j['offsets'] as List?)?.map((e) => e as int).toList() ??
        [j['beforeMin'] as int? ?? 15];
    return PrayerAlarm(
      atTime: j['atTime'] as bool? ?? false,
      atTimeSound:
          AdhanSound.fromId(j['atSound'] as String? ?? legacySound.id),
      beforeEnabled: j['before'] as bool? ?? false,
      beforeOffsets: offsets.isEmpty ? const [15] : offsets,
      beforeSound:
          AdhanSound.fromId(j['beforeSound'] as String? ?? legacySound.id),
    );
  }
}

/// The whole prayer-notification configuration (one [PrayerAlarm] per slot).
class PrayerNotificationConfig {
  final Map<PrayerSlot, PrayerAlarm> alarms;
  const PrayerNotificationConfig(this.alarms);

  PrayerAlarm alarmFor(PrayerSlot slot) => alarms[slot] ?? const PrayerAlarm();

  PrayerNotificationConfig withAlarm(PrayerSlot slot, PrayerAlarm alarm) {
    final next = Map<PrayerSlot, PrayerAlarm>.from(alarms);
    next[slot] = alarm;
    return PrayerNotificationConfig(next);
  }

  /// Default (everything ON, as requested): the five canonical prayers ring at
  /// their time WITH the adhan, plus 30- and 10-minute-before reminders with a
  /// tone. Sunrise is excluded (it is not a salah). Users can still tune any of this.
  factory PrayerNotificationConfig.defaults() => PrayerNotificationConfig({
        for (final s in PrayerSlot.values)
          if (s != PrayerSlot.sunrise)
            s: const PrayerAlarm(
              atTime: true,
              atTimeSound: AdhanSound.meccaFull,
              beforeEnabled: true,
              beforeOffsets: [30, 10],
              beforeSound: AdhanSound.chime,
            ),
      });

  String encode() => jsonEncode(
      {for (final e in alarms.entries) e.key.name: e.value.toJson()});

  static PrayerNotificationConfig decode(String? raw) {
    if (raw == null || raw.isEmpty) return PrayerNotificationConfig.defaults();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final out = <PrayerSlot, PrayerAlarm>{};
      for (final e in map.entries) {
        for (final slot in PrayerSlot.values) {
          if (slot.name == e.key) {
            out[slot] =
                PrayerAlarm.fromJson((e.value as Map).cast<String, dynamic>());
            break;
          }
        }
      }
      return out.isEmpty
          ? PrayerNotificationConfig.defaults()
          : PrayerNotificationConfig(out);
    } catch (_) {
      return PrayerNotificationConfig.defaults();
    }
  }
}
