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
  // Yumuşak ~5 sn çıngırak — "vakitten önce" hatırlatmanın varsayılanı
  // (res/raw/notif_chime). GENEL bildirimlerde de kullanılır → korunur.
  chime(id: 'chime', labelKey: 'notif.soundChime', file: 'notif_chime'),

  // ───── SESLİ VAKİT ANONSLARI — "X namazı vakti" konuşma kaydı. İLK KURULUMDA
  // her vaktin VARSAYILANI kendi anonsudur (sabah→Fajr … yatsı→İsha).
  vakitSabah(
      id: 'vakit_sabah',
      properName: 'Sabah namazı vakti (sesli)',
      file: 'vakit_sabah'),
  vakitOgle(
      id: 'vakit_ogle',
      properName: 'Öğle namazı vakti (sesli)',
      file: 'vakit_ogle'),
  vakitIkindi(
      id: 'vakit_ikindi',
      properName: 'İkindi namazı vakti (sesli)',
      file: 'vakit_ikindi'),
  vakitAksam(
      id: 'vakit_aksam',
      properName: 'Akşam namazı vakti (sesli)',
      file: 'vakit_aksam'),
  vakitYatsi(
      id: 'vakit_yatsi',
      properName: 'Yatsı namazı vakti (sesli)',
      file: 'vakit_yatsi'),

  // ───── ZİL SESLERİ — alternatif bildirim tonları (istenen vakte seçilebilir).
  toneNasheed(
      id: 'tone_nasheed',
      properName: 'İlahi (fon müziği)',
      file: 'tone_nasheed'),
  toneMyst(id: 'tone_myst', properName: 'Gizemli ton', file: 'tone_myst'),
  toneR021(id: 'tone_r021', properName: 'Zil 1', file: 'tone_r021'),
  toneR029(id: 'tone_r029', properName: 'Zil 2', file: 'tone_r029'),
  toneR057(id: 'tone_r057', properName: 'Zil 3', file: 'tone_r057'),
  toneR084(id: 'tone_r084', properName: 'Zil 4', file: 'tone_r084');

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
    // Kaldırılan eski müezzin/melodi id'leri → ezan kaybolmasın diye sesli SABAH
    // anonsuna taşınır (yeni per-prayer varsayılanlar reset ile de uygulanır).
    const removed = {
      'ahmed_nafees', 'mishary', 'hafiz_mustafa', 'masjid_haram', 'qari_kareem',
      'sheikh_jamac', 'karl_jenkins', 'salah_mansor',
      'mecca_full', 'mecca_maghrib', 'hassan2_full', 'commons', 'makkah',
      'harak', 'fakhri',
      'mel_neyud', 'mel_ney', 'mel_oud', 'mel_dogu', 'mel_huzur', 'mel_cingirak',
    };
    if (removed.contains(id)) return AdhanSound.vakitSabah;
    return AdhanSound.values.firstWhere((s) => s.id == id,
        orElse: () => AdhanSound.defaultTone);
  }

  /// Sesli vakit anonsları — her vaktin İLK-KURULUM varsayılanı buradandır.
  static const announces = [
    vakitSabah,
    vakitOgle,
    vakitIkindi,
    vakitAksam,
    vakitYatsi,
  ];

  /// Zil sesleri — alternatif bildirim tonları (herhangi bir vakte seçilebilir).
  static const ringtones = [
    toneNasheed,
    toneMyst,
    toneR021,
    toneR029,
    toneR057,
    toneR084,
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
  factory PrayerNotificationConfig.defaults() {
    // Her vaktin VARSAYILANI kendi sesli anonsudur (sabah→Fajr … yatsı→İsha);
    // vakitten önce yumuşak çıngırak. Sunrise namaz değil → hariç.
    const voice = {
      PrayerSlot.imsak: AdhanSound.vakitSabah,
      PrayerSlot.dhuhr: AdhanSound.vakitOgle,
      PrayerSlot.asr: AdhanSound.vakitIkindi,
      PrayerSlot.maghrib: AdhanSound.vakitAksam,
      PrayerSlot.isha: AdhanSound.vakitYatsi,
    };
    return PrayerNotificationConfig({
      for (final s in PrayerSlot.values)
        if (s != PrayerSlot.sunrise)
          s: PrayerAlarm(
            atTime: true,
            atTimeSound: voice[s] ?? AdhanSound.vakitSabah,
            beforeEnabled: true,
            beforeOffsets: const [30, 10],
            beforeSound: AdhanSound.chime,
          ),
    });
  }

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
