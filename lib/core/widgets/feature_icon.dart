import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';

/// The circular gold icon badge used by the home & "More" feature grids, with a
/// subtle, staggered pop-in animation so the grids feel alive as they appear.
/// [index] staggers each badge so they don't all animate in unison.
class FeatureIcon extends StatelessWidget {
  final IconData icon;
  final int index;
  final double size;
  final double padding;
  const FeatureIcon(this.icon,
      {super.key, this.index = 0, this.size = 24, this.padding = 12});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final badge = Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.gold.withValues(alpha: 0.13),
      ),
      // Dark themes → white glyph for max contrast/readability (the accent tint
      // stays in the badge background); light themes keep the coloured glyph.
      child: Icon(icon, color: c.isDark ? c.textPrimary : c.gold, size: size),
    );
    // Continuous, gentle "breathing" pulse — the duration is varied per icon so
    // the badges drift out of sync for an organic feel. Subtle (≤6%) and
    // transform-only, so it's cheap to keep running.
    return badge
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.06,
          duration: (1900 + (index % 6) * 180).ms,
          curve: Curves.easeInOut,
        );
  }
}
