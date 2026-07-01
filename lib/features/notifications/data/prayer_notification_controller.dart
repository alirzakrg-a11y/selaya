import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../prayer_times/domain/prayer.dart';
import '../domain/prayer_notification_settings.dart';

/// Holds the per-prayer notification configuration, persisted as JSON.
///
/// Rescheduling is triggered by callers (notification settings screen + app
/// lifecycle) via `prayerSchedulerProvider`, to keep this controller free of
/// scheduling concerns.
class PrayerNotificationController extends Notifier<PrayerNotificationConfig> {
  @override
  PrayerNotificationConfig build() {
    final prefs = ref.read(sharedPreferencesProvider);
    // TEK SEFERLİK (v1.0.320+): eski ezan/melodi sesleri kaldırıldı → mevcut
    // kullanıcıların kayıtlı seçimlerini YENİ per-prayer SESLİ vakit anonsu
    // varsayılanlarına sıfırla (silinen sesler zaten çalmaz; kullanıcı yine
    // değiştirebilir). İlk kurulumda decode() zaten defaults() döner.
    if (!(prefs.getBool('adhan_voices_reset_v1') ?? false)) {
      prefs.setBool('adhan_voices_reset_v1', true);
      final def = PrayerNotificationConfig.defaults();
      prefs.setString(PrefKeys.prayerNotifConfig, def.encode());
      return def;
    }
    return PrayerNotificationConfig.decode(
        prefs.getString(PrefKeys.prayerNotifConfig));
  }

  Future<void> _persist(PrayerNotificationConfig config) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.prayerNotifConfig, config.encode());
    state = config;
  }

  Future<void> setAlarm(PrayerSlot slot, PrayerAlarm alarm) =>
      _persist(state.withAlarm(slot, alarm));

  Future<void> toggleAtTime(PrayerSlot slot, bool value) =>
      setAlarm(slot, state.alarmFor(slot).copyWith(atTime: value));

  Future<void> toggleBefore(PrayerSlot slot, bool value) {
    final a = state.alarmFor(slot);
    // Enabling with no offsets selected seeds a sensible default.
    final offsets = value && a.beforeOffsets.isEmpty ? const [15] : a.beforeOffsets;
    return setAlarm(
        slot, a.copyWith(beforeEnabled: value, beforeOffsets: offsets));
  }

  /// Adds/removes a "minutes before" reminder (e.g. 20 and 10). Empty list
  /// turns the before section off.
  Future<void> toggleBeforeOffset(PrayerSlot slot, int minutes) {
    final a = state.alarmFor(slot);
    final set = List<int>.from(a.beforeOffsets);
    set.contains(minutes) ? set.remove(minutes) : set.add(minutes);
    set.sort((x, y) => y.compareTo(x)); // 20 before 10
    return setAlarm(slot,
        a.copyWith(beforeOffsets: set, beforeEnabled: set.isNotEmpty));
  }

  /// Tek "vakitten önce" süresi seç (combo box) — diğerlerini temizler.
  Future<void> setBeforeOffset(PrayerSlot slot, int minutes) {
    final a = state.alarmFor(slot);
    return setAlarm(
        slot, a.copyWith(beforeOffsets: [minutes], beforeEnabled: true));
  }

  Future<void> setAtTimeSound(PrayerSlot slot, AdhanSound sound) =>
      setAlarm(slot, state.alarmFor(slot).copyWith(atTimeSound: sound));

  Future<void> setBeforeSound(PrayerSlot slot, AdhanSound sound) =>
      setAlarm(slot, state.alarmFor(slot).copyWith(beforeSound: sound));
}

final prayerNotificationProvider =
    NotifierProvider<PrayerNotificationController, PrayerNotificationConfig>(
        PrayerNotificationController.new);

/// Whether the persistent "next prayer" status notification is enabled (Android).
class OngoingNotificationController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(PrefKeys.ongoingNotif) ??
      true; // persistent next-prayer status is ON by default

  Future<void> set(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.ongoingNotif, value);
    state = value;
  }
}

final ongoingNotificationProvider =
    NotifierProvider<OngoingNotificationController, bool>(
        OngoingNotificationController.new);

/// Whether the full-screen adhan alarm (screen-waking takeover at prayer time)
/// is enabled. ON by default; the user can turn it off from the alarm screen's
/// red button or in Settings — the at-time notification then still fires, just
/// without the full-screen takeover.
class FullScreenAdhanController extends Notifier<bool> {
  @override
  // Tam ekran ezan KALDIRILDI (kullanıcı 2026-06-15) — provider KALICI KAPALI:
  // eski kullanıcının pref'i true olsa bile full-screen takeover AÇILMAZ. Ezan
  // sesi native serviste çalmaya devam eder (full-screen'den bağımsız).
  bool build() => false;

  Future<void> set(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.fullScreenAdhan, value);
    state = value;
  }
}

final fullScreenAdhanProvider =
    NotifierProvider<FullScreenAdhanController, bool>(
        FullScreenAdhanController.new);

/// Bildirim titreşimi — global [prayerVibration]'ı (kanal kimliğinde kullanılır)
/// + prefs'i yönetir, reaktif. ON by default.
class NotifVibrationController extends Notifier<bool> {
  @override
  bool build() {
    final v =
        ref.read(sharedPreferencesProvider).getBool(PrefKeys.notifVibration) ??
            true;
    prayerVibration = v;
    return v;
  }

  Future<void> set(bool value) async {
    prayerVibration = value;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.notifVibration, value);
    state = value;
  }
}

final notifVibrationProvider =
    NotifierProvider<NotifVibrationController, bool>(
        NotifVibrationController.new);

/// Master switch for ALL prayer alerts (the at-time adhan + the before-time
/// reminders). ON by default; off → no prayer notifications are scheduled at all
/// (the persistent next-prayer status keeps its own [ongoingNotificationProvider]).
class PrayerAlertsController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(PrefKeys.prayerAlerts) ?? true;

  Future<void> set(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.prayerAlerts, value);
    state = value;
  }
}

final prayerAlertsProvider =
    NotifierProvider<PrayerAlertsController, bool>(PrayerAlertsController.new);
