import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The circular gold icon badge used by the home & "More" feature grids.
/// STATİK (animasyonsuz) — kullanıcı isteği: eski telefonlarda akıcılık için
/// ana ekran/vakit ekranı animasyonları kaldırıldı. [index] artık kullanılmıyor
/// ama imza korunuyor (çağıranlar değişmesin).
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
    return badge;
  }
}
