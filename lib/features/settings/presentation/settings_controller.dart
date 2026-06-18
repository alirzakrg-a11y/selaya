import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../prayer_times/domain/prayer.dart';

/// Prayer-time calculation methods exposed in onboarding & settings.
///
/// The adhan-specific parameters for each are resolved in
/// `prayer_times/domain/calc_params.dart` (keeps this file free of the adhan dep).
enum CalcMethod {
  diyanet('diyanet', 'Diyanet İşleri Başkanlığı (Türkiye)', 'Diyanet (Turkey)'),
  mwl('mwl', 'Dünya İslam Birliği', 'Muslim World League'),
  egypt('egypt', 'Mısır Genel Araştırma Kurumu', 'Egyptian General Authority'),
  karachi('karachi', 'Karaçi İslami Bilimler Üniversitesi', 'University of Karachi'),
  ummAlQura('umm_al_qura', 'Ümmü\'l-Kura, Mekke', 'Umm al-Qura, Makkah'),
  dubai('dubai', 'Dubai (Körfez)', 'Dubai (Gulf)'),
  moonsighting('moonsighting', 'Moonsighting Committee', 'Moonsighting Committee'),
  northAmerica('north_america', 'Kuzey Amerika (ISNA)', 'North America (ISNA)'),
  kuwait('kuwait', 'Kuveyt', 'Kuwait'),
  qatar('qatar', 'Katar', 'Qatar'),
  singapore('singapore', 'Singapur (MUIS)', 'Singapore (MUIS)'),
  tehran('tehran', 'Tahran Jeofizik Enstitüsü', 'Tehran (Geophysics)'),
  jafari('jafari', 'Caferi (İsnâ Aşeriyye)', 'Jafari (Ithna-Ashari)'),
  franceUOIF('france_uoif', 'Fransa (UOIF)', 'France (UOIF)'),
  russia('russia', 'Rusya', 'Russia'),
  morocco('morocco', 'Fas', 'Morocco'),
  indonesia('indonesia', 'Endonezya (Kemenag)', 'Indonesia (Kemenag)'),
  tunisia('tunisia', 'Tunus', 'Tunisia');

  const CalcMethod(this.id, this.labelTr, this.labelEn);
  final String id;
  final String labelTr;
  final String labelEn;

  String label(String lang) => lang == 'tr' ? labelTr : labelEn;

  static CalcMethod fromId(String id) =>
      CalcMethod.values.firstWhere((m) => m.id == id, orElse: () => CalcMethod.diyanet);
}

@immutable
class AppSettings {
  final ThemeMode themeMode;
  final bool amoled;
  final AppPalette palette;
  final double textScale;
  final CalcMethod calcMethod;
  final String cityId; // 'current' => use GPS coords below
  final double? gpsLat;
  final double? gpsLng;
  final String? gpsName;

  // Fine-tuning (Round-7)
  final Map<PrayerSlot, int> offsets; // per-prayer minute adjustment
  final int hijriOffsetDays; // ±days applied to the Hijri date display
  final bool hanafiAsr; // Hanafi (double shadow) Asr instead of standard
  final bool smartSilent; // auto-silence the phone during prayer & Friday windows

  const AppSettings({
    this.themeMode = ThemeMode.dark, // Koyu yeşil + parlak altın varsayılan (mockup)
    this.amoled = false, // saf siyah değil — koyu yeşil zemin
    this.palette = AppPalette.green,
    this.textScale = 1.0,
    this.calcMethod = CalcMethod.diyanet,
    this.cityId = 'istanbul',
    this.gpsLat,
    this.gpsLng,
    this.gpsName,
    this.offsets = const {},
    this.hijriOffsetDays = 0,
    this.hanafiAsr = false,
    this.smartSilent = false,
  });

  bool get usesGps => cityId == 'current' && gpsLat != null && gpsLng != null;

  int offsetFor(PrayerSlot slot) => offsets[slot] ?? 0;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? amoled,
    AppPalette? palette,
    double? textScale,
    CalcMethod? calcMethod,
    String? cityId,
    double? gpsLat,
    double? gpsLng,
    String? gpsName,
    Map<PrayerSlot, int>? offsets,
    int? hijriOffsetDays,
    bool? hanafiAsr,
    bool? smartSilent,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        amoled: amoled ?? this.amoled,
        palette: palette ?? this.palette,
        textScale: textScale ?? this.textScale,
        calcMethod: calcMethod ?? this.calcMethod,
        cityId: cityId ?? this.cityId,
        gpsLat: gpsLat ?? this.gpsLat,
        gpsLng: gpsLng ?? this.gpsLng,
        gpsName: gpsName ?? this.gpsName,
        offsets: offsets ?? this.offsets,
        hijriOffsetDays: hijriOffsetDays ?? this.hijriOffsetDays,
        hanafiAsr: hanafiAsr ?? this.hanafiAsr,
        smartSilent: smartSilent ?? this.smartSilent,
      );
}

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    return AppSettings(
      themeMode: _modeFromName(_prefs.getString(PrefKeys.themeMode)),
      amoled: _prefs.getBool(PrefKeys.amoled) ?? false,
      palette: AppPalette.fromId(
          _prefs.getString(PrefKeys.palette) ?? AppPalette.green.name),
      textScale: _prefs.getDouble(PrefKeys.textScale) ?? 1.0,
      calcMethod: CalcMethod.fromId(_prefs.getString(PrefKeys.calcMethod) ?? 'diyanet'),
      cityId: _prefs.getString(PrefKeys.cityId) ?? 'istanbul',
      gpsLat: _prefs.getDouble(PrefKeys.gpsLat),
      gpsLng: _prefs.getDouble(PrefKeys.gpsLng),
      gpsName: _prefs.getString(PrefKeys.gpsName),
      offsets: _decodeOffsets(_prefs.getString(PrefKeys.prayerOffsets)),
      hijriOffsetDays: _prefs.getInt(PrefKeys.hijriOffsetDays) ?? 0,
      hanafiAsr: _prefs.getBool(PrefKeys.hanafiAsr) ?? false,
      smartSilent: _prefs.getBool(PrefKeys.smartSilent) ?? false,
    );
  }

  /// Switch to GPS-detected location (prayer times computed from raw coords).
  Future<void> setCurrentLocation(double lat, double lng, String name) async {
    await _prefs.setDouble(PrefKeys.gpsLat, lat);
    await _prefs.setDouble(PrefKeys.gpsLng, lng);
    await _prefs.setString(PrefKeys.gpsName, name);
    await _prefs.setString(PrefKeys.cityId, 'current');
    state = state.copyWith(
        cityId: 'current', gpsLat: lat, gpsLng: lng, gpsName: name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(PrefKeys.themeMode, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setAmoled(bool value) async {
    await _prefs.setBool(PrefKeys.amoled, value);
    state = state.copyWith(amoled: value);
  }

  /// Switch the colour palette (gold / İslami Yeşil). Persisted; the app
  /// rebuilds its light & dark themes from the new palette immediately.
  Future<void> setPalette(AppPalette palette) async {
    await _prefs.setString(PrefKeys.palette, palette.name);
    state = state.copyWith(palette: palette);
  }

  /// Font-size multiplier (#22 senior-friendly large-text mode). Clamped 0.9–1.35.
  Future<void> setTextScale(double v) async {
    final s = v.clamp(0.9, 1.35);
    await _prefs.setDouble(PrefKeys.textScale, s);
    state = state.copyWith(textScale: s);
  }

  Future<void> setCalcMethod(CalcMethod method) async {
    await _prefs.setString(PrefKeys.calcMethod, method.id);
    state = state.copyWith(calcMethod: method);
  }

  Future<void> setCity(String cityId) async {
    await _prefs.setString(PrefKeys.cityId, cityId);
    state = state.copyWith(cityId: cityId);
  }

  /// Per-prayer minute offset (e.g. +2 / -1). Pass 0 to clear that slot.
  Future<void> setOffset(PrayerSlot slot, int minutes) async {
    final next = Map<PrayerSlot, int>.from(state.offsets);
    if (minutes == 0) {
      next.remove(slot);
    } else {
      next[slot] = minutes;
    }
    await _prefs.setString(PrefKeys.prayerOffsets, _encodeOffsets(next));
    state = state.copyWith(offsets: next);
  }

  Future<void> setHijriOffset(int days) async {
    await _prefs.setInt(PrefKeys.hijriOffsetDays, days);
    state = state.copyWith(hijriOffsetDays: days);
  }

  Future<void> setHanafiAsr(bool value) async {
    await _prefs.setBool(PrefKeys.hanafiAsr, value);
    state = state.copyWith(hanafiAsr: value);
  }

  /// Smart Silent (#6.2): auto-silence the phone during prayer & Friday windows.
  Future<void> setSmartSilent(bool value) async {
    await _prefs.setBool(PrefKeys.smartSilent, value);
    state = state.copyWith(smartSilent: value);
  }

  static String _encodeOffsets(Map<PrayerSlot, int> m) =>
      jsonEncode({for (final e in m.entries) e.key.name: e.value});

  static Map<PrayerSlot, int> _decodeOffsets(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final out = <PrayerSlot, int>{};
      for (final e in map.entries) {
        if (e.value is! int || e.value == 0) continue;
        for (final slot in PrayerSlot.values) {
          if (slot.name == e.key) {
            out[slot] = e.value as int;
            break;
          }
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  static ThemeMode _modeFromName(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark, // varsayılan: koyu yeşil + parlak altın
      };
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
