import 'package:flutter/material.dart';

/// Typography system.
/// UI font: Plus Jakarta Sans (premium geometric sans, full Turkish glyphs).
/// Arabic/Quran font: Amiri.
///
/// PERF (kullanıcı 2026-06-14 "ilk açılışta + her yerde donuyor"): fontlar artık
/// `google_fonts` ile ÇALIŞMA ANINDA İNTERNETTEN çekilmiyor — `assets/fonts/`
/// içinde PAKETLİ (yerel). Eskiden ilk kullanımda font indirilene kadar metin
/// yedek fontla çiziliyor, font gelince asenkron değişip tüm ekran yeniden
/// yerleşiyordu; Amiri (Arapça) ayrıca ilk Kur'an açılışında yükleniyordu =
/// "ilk açılış + Kur'an + her yerde donma". Yerel font = ağ yok, anında çizim.
abstract final class AppTypography {
  static const _ui = 'PlusJakartaSans';
  static const _arabic = 'Amiri';

  static TextTheme textTheme(Color primary, Color secondary) {
    TextStyle s(double size, FontWeight w, Color c,
            {double? height, double? spacing}) =>
        TextStyle(
          fontFamily: _ui,
          fontSize: size,
          fontWeight: w,
          color: c,
          height: height,
          letterSpacing: spacing,
        );

    return TextTheme(
      displayLarge: s(40, FontWeight.w700, primary, height: 1.1, spacing: -0.5),
      displayMedium: s(32, FontWeight.w700, primary, height: 1.12, spacing: -0.4),
      displaySmall: s(28, FontWeight.w700, primary, height: 1.15),
      headlineLarge: s(26, FontWeight.w700, primary, height: 1.2),
      headlineMedium: s(22, FontWeight.w600, primary, height: 1.25),
      headlineSmall: s(20, FontWeight.w600, primary, height: 1.3),
      titleLarge: s(18, FontWeight.w600, primary, height: 1.3),
      titleMedium: s(16, FontWeight.w600, primary, height: 1.35),
      titleSmall: s(14, FontWeight.w600, primary, height: 1.4),
      bodyLarge: s(16, FontWeight.w400, primary, height: 1.5),
      bodyMedium: s(14, FontWeight.w400, secondary, height: 1.5),
      bodySmall: s(13, FontWeight.w400, secondary, height: 1.45),
      labelLarge: s(14, FontWeight.w600, primary, height: 1.2, spacing: 0.2),
      labelMedium: s(12, FontWeight.w600, secondary, height: 1.2, spacing: 0.3),
      labelSmall: s(11, FontWeight.w500, secondary, height: 1.2, spacing: 0.4),
    );
  }

  /// Arabic / Quran text style.
  static TextStyle arabic({
    double fontSize = 28,
    Color? color,
    double height = 1.95,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontFamily: _arabic,
        fontSize: fontSize,
        color: color,
        height: height,
        fontWeight: weight,
      );

  /// Big tabular-figure countdown style.
  static TextStyle countdown(Color color, {double fontSize = 44}) => TextStyle(
        fontFamily: _ui,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Tabular figures for prayer times / clocks.
  static TextStyle tabular(TextStyle base) =>
      base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
