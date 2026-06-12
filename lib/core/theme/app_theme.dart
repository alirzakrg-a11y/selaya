import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the SELAYA [ThemeData] for dark (default) and light modes.
abstract final class AppTheme {
  /// Light theme for the chosen [palette] (gold default / İslami Yeşil).
  static ThemeData light({AppPalette palette = AppPalette.gold}) =>
      _build(Brightness.light,
          SelayaColors.resolve(palette, Brightness.light));

  /// Dark theme for the chosen [palette], optionally pure-black AMOLED.
  static ThemeData darkMode(
          {bool amoled = false, AppPalette palette = AppPalette.gold}) =>
      _build(Brightness.dark,
          SelayaColors.resolve(palette, Brightness.dark, amoled: amoled));

  static ThemeData _build(Brightness brightness, SelayaColors c) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: c.gold,
      brightness: brightness,
    ).copyWith(
      primary: c.gold,
      onPrimary: isDark ? const Color(0xFF1A1203) : Colors.white,
      secondary: c.accent,
      surface: c.surface,
      onSurface: c.textPrimary,
      error: c.danger,
    );

    final textTheme = AppTypography.textTheme(c.textPrimary, c.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      colorScheme: scheme,
      textTheme: textTheme,
      primaryColor: c.gold,
      dividerColor: c.border,
      splashFactory: InkRipple.splashFactory,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: c.textPrimary, size: 22),
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: 22),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: c.surfaceAlt,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        showDragHandle: true,
        dragHandleColor: c.border,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceAlt,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.gold,
        linearTrackColor: c.border,
        circularTrackColor: c.border,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.gold : c.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.gold.withValues(alpha: 0.35)
              : c.border,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      splashColor: c.gold.withValues(alpha: 0.08),
      highlightColor: c.gold.withValues(alpha: 0.05),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
