import 'package:flutter/material.dart';

/// Raw brand constants — identical across light & dark.
/// Theme-aware semantic tokens live in [SelayaColors] (a [ThemeExtension]).
abstract final class AppColors {
  // ── Signature gold family ──────────────────────────────────────────
  static const Color goldSoft = Color(0xFFF6D98C);
  static const Color goldBright = Color(0xFFF4D27A);
  static const Color gold = Color(0xFFE0B250);
  static const Color goldDeep = Color(0xFFB6862F);
  static const List<Color> goldGradient = [goldSoft, gold, goldDeep];

  // ── Secondary accent (SELAYA AI / stories) ───────────────────────────
  static const Color accent = Color(0xFF7E7BF2);
  static const Color accentAlt = Color(0xFF9A6CF0);
  static const List<Color> accentGradient = [accent, accentAlt];

  // ── Status ──────────────────────────────────────────────────────────
  static const Color success = Color(0xFF46D08A);
  static const Color danger = Color(0xFFF2616B);
  static const Color info = Color(0xFF54B8E6);

  // ── Dark palette (default) ───────────────────────────────────────────
  static const Color darkBg = Color(0xFF05070D);
  static const Color darkBgAmoled = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0E1322);
  static const Color darkSurfaceAlt = Color(0xFF141A2B);
  static const Color darkBorder = Color(0x1FFFFFFF); // white @ 12%
  static const Color darkGlass = Color(0x0DFFFFFF); // white @ 5%
  static const Color darkTextPrimary = Color(0xFFF4F6FB);
  static const Color darkTextSecondary = Color(0xFF9AA3B8);
  static const Color darkTextTertiary = Color(0xFF5E6680);
  static const List<Color> prayerActiveDark = [Color(0xFF3A2A12), Color(0xFF6B4E1E)];

  // ── Light palette (redesign: sade/aydınlık, düz zemin) ───────────────
  // Hafif sıcak krem zemin + neredeyse beyaz kartlar; desen/gölge yok, kart
  // tanımı net bir kenarlıkla verilir. surfaceAlt beyazdan AYRI tutulur ki
  // beyaz yüzeylerdeki metin alanı dolguları (fillColor) görünür kalsın.
  static const Color lightBg = Color(0xFFEFEDE6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFFAF8F3);
  static const Color lightBorder = Color(0x1A000000); // black @ 10%
  static const Color lightGlass = Color(0x99FFFFFF);
  static const Color lightTextPrimary = Color(0xFF14171F);
  static const Color lightTextSecondary = Color(0xFF5A6172);
  static const Color lightTextTertiary = Color(0xFF8A91A3);
  static const List<Color> prayerActiveLight = [Color(0xFFF7E9C8), Color(0xFFEAD49A)];

  // ── İslami Yeşil palette (#23) ───────────────────────────────────────
  // Deep emerald (dark) / soft sage-cream (light); the signature gold family
  // above is reused for the accents ("altın detaylar").
  static const Color greenDarkBg = Color(0xFF06140E);
  static const Color greenDarkBgAmoled = Color(0xFF000000);
  static const Color greenDarkSurface = Color(0xFF0C2018);
  static const Color greenDarkSurfaceAlt = Color(0xFF12291E);
  static const Color greenDarkTextPrimary = Color(0xFFF0F5F0);
  static const Color greenDarkTextSecondary = Color(0xFF9DB2A4);
  static const Color greenDarkTextTertiary = Color(0xFF5C7165);
  static const List<Color> prayerActiveDarkGreen = [Color(0xFF15321F), Color(0xFF2A6043)];

  // ── Parlak altın (mockup "premium gold" hissi) + altın kart kenarlığı ──
  // Koyu yeşil zeminde kullanılan daha parlak/doygun altın ailesi ve kartlara
  // ince altın çerçeve (mockup'taki gold-border kartlar).
  static const Color goldVivid = Color(0xFFEAC25C); // parlak altın
  static const Color goldLumin = Color(0xFFF7E3A6); // ışıltılı vurgu
  static const Color goldBorderDark = Color(0x40E6B84F); // altın @ ~25% (kart kenarı)
  static const List<Color> goldGradientVivid = [goldLumin, goldVivid, Color(0xFFC79A3A)];

  static const Color greenLightBg = Color(0xFFECF1E6);
  static const Color greenLightSurface = Color(0xFFFBFCF7);
  static const Color greenLightSurfaceAlt = Color(0xFFF1F5EB);
  static const Color greenLightTextPrimary = Color(0xFF13201A);
  static const Color greenLightTextSecondary = Color(0xFF53635A);
  static const Color greenLightTextTertiary = Color(0xFF838F87);
  static const List<Color> prayerActiveLightGreen = [Color(0xFFD9E8CF), Color(0xFFBFD9AE)];
}

/// Selectable colour palette (#23). [gold] is the signature default; [green]
/// is the "İslami Yeşil" alternative — deep green / cream base with the gold
/// accents kept as details. Orthogonal to the light/dark/AMOLED mode.
enum AppPalette {
  gold,
  green,
  blue, // Gece Mavisi
  purple, // Mor
  rose, // Gül Kurusu
  teal; // Turkuaz

  static AppPalette fromId(String? id) => AppPalette.values
      .firstWhere((p) => p.name == id, orElse: () => AppPalette.gold);
}

/// Theme-aware semantic colors. Access via `context.colors`.
@immutable
class SelayaColors extends ThemeExtension<SelayaColors> {
  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color glass;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color gold;
  final Color goldBright;
  final Color goldDeep;
  final Color accent;
  final Color success;
  final Color danger;
  final List<Color> goldGradient;
  final List<Color> prayerActive;

  const SelayaColors({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.glass,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.gold,
    required this.goldBright,
    required this.goldDeep,
    required this.accent,
    required this.success,
    required this.danger,
    required this.goldGradient,
    required this.prayerActive,
  });

  bool get isDark => brightness == Brightness.dark;

  /// Altın zemin ÜSTÜNDEKİ koyu metin/ikon rengi (gold buton, seçili çip, gold
  /// kart, isToday). 24+ ekranda ham `Color(0xFF1A1203)` olarak geçiyordu → tek
  /// kaynak. Tema-bağımsız (gold accent her iki temada da aynı).
  Color get onGold => const Color(0xFF1A1203);
  Color get onGoldMuted => const Color(0xCC1A1203);

  static const SelayaColors dark = SelayaColors(
    brightness: Brightness.dark,
    bg: AppColors.darkBg,
    surface: AppColors.darkSurface,
    surfaceAlt: AppColors.darkSurfaceAlt,
    border: AppColors.darkBorder,
    glass: AppColors.darkGlass,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textTertiary: AppColors.darkTextTertiary,
    gold: AppColors.gold,
    goldBright: AppColors.goldBright,
    goldDeep: AppColors.goldDeep,
    accent: AppColors.accent,
    success: AppColors.success,
    danger: AppColors.danger,
    goldGradient: AppColors.goldGradient,
    prayerActive: AppColors.prayerActiveDark,
  );

  static const SelayaColors light = SelayaColors(
    brightness: Brightness.light,
    bg: AppColors.lightBg,
    surface: AppColors.lightSurface,
    surfaceAlt: AppColors.lightSurfaceAlt,
    border: AppColors.lightBorder,
    glass: AppColors.lightGlass,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textTertiary: AppColors.lightTextTertiary,
    gold: AppColors.goldDeep,
    goldBright: AppColors.gold,
    goldDeep: Color(0xFF8A641F),
    accent: AppColors.accent,
    success: Color(0xFF1F9D63),
    danger: Color(0xFFD6434D),
    goldGradient: [AppColors.gold, AppColors.goldDeep, Color(0xFF8A641F)],
    prayerActive: AppColors.prayerActiveLight,
  );

  // ── İslami Yeşil (#23): deep-green / cream base, gold accents retained ──
  static const SelayaColors darkGreen = SelayaColors(
    brightness: Brightness.dark,
    bg: AppColors.greenDarkBg,
    surface: AppColors.greenDarkSurface,
    surfaceAlt: AppColors.greenDarkSurfaceAlt,
    border: AppColors.goldBorderDark, // altın çerçeveli kartlar (mockup)
    glass: AppColors.darkGlass,
    textPrimary: AppColors.greenDarkTextPrimary,
    textSecondary: AppColors.greenDarkTextSecondary,
    textTertiary: AppColors.greenDarkTextTertiary,
    gold: AppColors.goldVivid, // parlak altın
    goldBright: AppColors.goldLumin,
    goldDeep: AppColors.goldDeep,
    accent: AppColors.accent,
    success: AppColors.success,
    danger: AppColors.danger,
    goldGradient: AppColors.goldGradientVivid,
    prayerActive: AppColors.prayerActiveDarkGreen,
  );

  static const SelayaColors lightGreen = SelayaColors(
    brightness: Brightness.light,
    bg: AppColors.greenLightBg,
    surface: AppColors.greenLightSurface,
    surfaceAlt: AppColors.greenLightSurfaceAlt,
    border: AppColors.lightBorder,
    glass: AppColors.lightGlass,
    textPrimary: AppColors.greenLightTextPrimary,
    textSecondary: AppColors.greenLightTextSecondary,
    textTertiary: AppColors.greenLightTextTertiary,
    gold: AppColors.goldDeep,
    goldBright: AppColors.gold,
    goldDeep: Color(0xFF8A641F),
    accent: AppColors.accent,
    success: Color(0xFF1F9D63),
    danger: Color(0xFFD6434D),
    goldGradient: [AppColors.gold, AppColors.goldDeep, Color(0xFF8A641F)],
    prayerActive: AppColors.prayerActiveLightGreen,
  );

  /// The active [SelayaColors] for a [palette] + [brightness] (+ AMOLED for dark).
  /// Single source of truth for theme resolution (used by [AppTheme]).
  static SelayaColors resolve(AppPalette palette, Brightness brightness,
      {bool amoled = false}) {
    switch (palette) {
      case AppPalette.gold:
        if (brightness == Brightness.light) return light;
        return amoled
            ? dark.copyWith(
                bg: AppColors.darkBgAmoled,
                surface: const Color(0xFF0A0C12),
                surfaceAlt: const Color(0xFF11141C),
              )
            : dark;
      case AppPalette.green:
        if (brightness == Brightness.light) return lightGreen;
        return amoled
            ? darkGreen.copyWith(
                bg: AppColors.greenDarkBgAmoled,
                surface: const Color(0xFF05100B),
                surfaceAlt: const Color(0xFF081610),
              )
            : darkGreen;
      // ── Extra palettes (#23 cont.): a tinted base + a distinct signature
      // accent (the `gold*` fields ARE the accent family used app-wide). ──
      case AppPalette.blue: // Gece Mavisi
        if (brightness == Brightness.light) {
          return light.copyWith(
            gold: const Color(0xFF3A5E9E),
            goldBright: const Color(0xFF5E8BD0),
            goldDeep: const Color(0xFF2E4B7E),
            goldGradient: const [
              Color(0xFF5E8BD0),
              Color(0xFF3A5E9E),
              Color(0xFF2E4B7E)
            ],
          );
        }
        return (amoled
                ? dark.copyWith(
                    bg: const Color(0xFF000000),
                    surface: const Color(0xFF070A11),
                    surfaceAlt: const Color(0xFF0C1220))
                : dark.copyWith(
                    bg: const Color(0xFF060A14),
                    surface: const Color(0xFF0D1626),
                    surfaceAlt: const Color(0xFF131F36)))
            .copyWith(
          gold: const Color(0xFF5E8BD0),
          goldBright: const Color(0xFF82A8E6),
          goldDeep: const Color(0xFF3A5E9E),
          goldGradient: const [
            Color(0xFF82A8E6),
            Color(0xFF5E8BD0),
            Color(0xFF3A5E9E)
          ],
          prayerActive: const [Color(0xFF13243F), Color(0xFF2C5088)],
        );
      case AppPalette.purple: // Mor
        if (brightness == Brightness.light) {
          return light.copyWith(
            gold: const Color(0xFF7A4FB0),
            goldBright: const Color(0xFF9F77D4),
            goldDeep: const Color(0xFF5E3A8A),
            goldGradient: const [
              Color(0xFF9F77D4),
              Color(0xFF7A4FB0),
              Color(0xFF5E3A8A)
            ],
          );
        }
        return (amoled
                ? dark.copyWith(
                    bg: const Color(0xFF000000),
                    surface: const Color(0xFF0B0711),
                    surfaceAlt: const Color(0xFF130C1E))
                : dark.copyWith(
                    bg: const Color(0xFF0C0815),
                    surface: const Color(0xFF170E24),
                    surfaceAlt: const Color(0xFF201634)))
            .copyWith(
          gold: const Color(0xFF9F77D4),
          goldBright: const Color(0xFFBC9BE8),
          goldDeep: const Color(0xFF7A4FB0),
          goldGradient: const [
            Color(0xFFBC9BE8),
            Color(0xFF9F77D4),
            Color(0xFF7A4FB0)
          ],
          prayerActive: const [Color(0xFF251640), Color(0xFF482E72)],
        );
      case AppPalette.rose: // Gül Kurusu
        if (brightness == Brightness.light) {
          return light.copyWith(
            gold: const Color(0xFFAE5476),
            goldBright: const Color(0xFFD17C95),
            goldDeep: const Color(0xFF8C3E5C),
            goldGradient: const [
              Color(0xFFD17C95),
              Color(0xFFAE5476),
              Color(0xFF8C3E5C)
            ],
          );
        }
        return (amoled
                ? dark.copyWith(
                    bg: const Color(0xFF000000),
                    surface: const Color(0xFF110710),
                    surfaceAlt: const Color(0xFF1C0C18))
                : dark.copyWith(
                    bg: const Color(0xFF140810),
                    surface: const Color(0xFF240E1A),
                    surfaceAlt: const Color(0xFF311526)))
            .copyWith(
          gold: const Color(0xFFD17C95),
          goldBright: const Color(0xFFE89DB2),
          goldDeep: const Color(0xFFAE5476),
          goldGradient: const [
            Color(0xFFE89DB2),
            Color(0xFFD17C95),
            Color(0xFFAE5476)
          ],
          prayerActive: const [Color(0xFF3C1626), Color(0xFF6E2E50)],
        );
      case AppPalette.teal: // Turkuaz
        if (brightness == Brightness.light) {
          return light.copyWith(
            gold: const Color(0xFF2A8676),
            goldBright: const Color(0xFF3FB5A4),
            goldDeep: const Color(0xFF1F6356),
            goldGradient: const [
              Color(0xFF3FB5A4),
              Color(0xFF2A8676),
              Color(0xFF1F6356)
            ],
          );
        }
        return (amoled
                ? dark.copyWith(
                    bg: const Color(0xFF000000),
                    surface: const Color(0xFF05100C),
                    surfaceAlt: const Color(0xFF0A1814))
                : dark.copyWith(
                    bg: const Color(0xFF05130F),
                    surface: const Color(0xFF0B1F1A),
                    surfaceAlt: const Color(0xFF112823)))
            .copyWith(
          gold: const Color(0xFF3FB5A4),
          goldBright: const Color(0xFF5FD8C5),
          goldDeep: const Color(0xFF2A8676),
          goldGradient: const [
            Color(0xFF5FD8C5),
            Color(0xFF3FB5A4),
            Color(0xFF2A8676)
          ],
          prayerActive: const [Color(0xFF0F2E28), Color(0xFF266056)],
        );
    }
  }

  @override
  SelayaColors copyWith({
    Brightness? brightness,
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? glass,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? gold,
    Color? goldBright,
    Color? goldDeep,
    Color? accent,
    Color? success,
    Color? danger,
    List<Color>? goldGradient,
    List<Color>? prayerActive,
  }) {
    return SelayaColors(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      glass: glass ?? this.glass,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      gold: gold ?? this.gold,
      goldBright: goldBright ?? this.goldBright,
      goldDeep: goldDeep ?? this.goldDeep,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      goldGradient: goldGradient ?? this.goldGradient,
      prayerActive: prayerActive ?? this.prayerActive,
    );
  }

  @override
  SelayaColors lerp(ThemeExtension<SelayaColors>? other, double t) {
    if (other is! SelayaColors) return this;
    List<Color> lerpList(List<Color> a, List<Color> b) => [
          for (var i = 0; i < a.length; i++)
            Color.lerp(a[i], b[i], t) ?? a[i],
        ];
    return SelayaColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldBright: Color.lerp(goldBright, other.goldBright, t)!,
      goldDeep: Color.lerp(goldDeep, other.goldDeep, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      goldGradient: lerpList(goldGradient, other.goldGradient),
      prayerActive: lerpList(prayerActive, other.prayerActive),
    );
  }
}

extension SelayaColorsX on BuildContext {
  /// Theme-aware SELAYA palette.
  SelayaColors get colors =>
      Theme.of(this).extension<SelayaColors>() ?? SelayaColors.dark;
}
