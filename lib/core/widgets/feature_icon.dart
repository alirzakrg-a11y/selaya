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
    // TEK-SEFERLİK "pop-in" — ızgara belirince canlı görünür, sonra STATİK.
    // ÖNCEDEN repeat(reverse:true) ile SONSUZ "nefes"ti → "Daha Fazla" gibi
    // ikon-dolu (ve tembel OLMAYAN) listelerde görünen/görünmeyen TÜM ikonlar
    // sürekli 60fps çizilip her karede tüm ekranı invalidate ediyordu →
    // kaydırırken KİLİTLENME. fadeIn/scaleXY paint-only (relayout yok) ve
    // animasyon bitince çizim DURUR → ekran boşa düşebilir.
    return badge
        .animate()
        .fadeIn(duration: 250.ms, delay: ((index % 8) * 35).ms)
        .scaleXY(
          begin: 0.85,
          end: 1.0,
          duration: 300.ms,
          curve: Curves.easeOutBack,
        );
  }
}
