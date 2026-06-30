import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Signature SELAYA backdrop: a dark vertical gradient with a soft gold glow
/// and a faint Islamic 8-pointed-star (khatam) tessellation drawn in code —
/// fully offline, no image assets needed.
class GeometricBackground extends StatelessWidget {
  final Widget? child;
  final List<Color>? gradientColors;
  final double patternOpacity;
  final Alignment glowAlignment;
  final Color? glowColor;

  const GeometricBackground({
    super.key,
    this.child,
    this.gradientColors,
    this.patternOpacity = 0.05,
    this.glowAlignment = const Alignment(0, -1.05),
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // ── Sade aydınlık tema (redesign): desen + parıltı + gradyan YOK. Düz,
    // sakin tek renk zemin = olabildiğince basit görünüm. Koyu tema imza
    // yıldız-deseni + altın parıltısını korur. ──────────────────────────────
    if (!colors.isDark) {
      final flatBg = (gradientColors != null && gradientColors!.isNotEmpty)
          ? gradientColors!.first
          : colors.bg;
      return ColoredBox(
        color: flatBg,
        child: child ?? const SizedBox.shrink(),
      );
    }

    final grad = gradientColors ??
        (colors.isDark
            ? [colors.bg, colors.surface, colors.bg]
            : [colors.bg, colors.surfaceAlt, colors.bg]);
    final glow = glowColor ?? colors.gold;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: grad,
        ),
      ),
      child: Stack(
        children: [
          // soft radial glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: glowAlignment,
                  radius: 1.1,
                  colors: [
                    glow.withValues(alpha: colors.isDark ? 0.16 : 0.10),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.55],
                ),
              ),
            ),
          ),
          // geometric star tessellation — RepaintBoundary + raster ipuçları: ~1000
          // çizgili yıldız yolu BİR KEZ rasterize edilip katman olarak cache'lenir
          // (her mount/RefreshIndicator/geçişte yeniden çizilmesin → ilk-kare cila).
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                willChange: false,
                painter: StarPatternPainter(
                  color: colors.gold.withValues(alpha: patternOpacity),
                ),
              ),
            ),
          ),
          if (child != null) Positioned.fill(child: child!),
        ],
      ),
    );
  }
}

class StarPatternPainter extends CustomPainter {
  final Color color;
  const StarPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const cell = 78.0;
    final r = cell * 0.46;
    for (double y = -cell; y < size.height + cell; y += cell) {
      for (double x = -cell; x < size.width + cell; x += cell) {
        _drawStar(canvas, Offset(x, y), r, paint);
      }
    }
  }

  /// 8-pointed star = two overlapping squares (one rotated 45°).
  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    for (final phase in [0.0, math.pi / 4]) {
      final path = Path();
      for (int i = 0; i < 4; i++) {
        final a = phase + i * math.pi / 2;
        final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(StarPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
