import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'gold_icon.dart';

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
      // Simgeler GRADYANLI parlak altın (kullanıcı 2026-06-18: "gradyanlı böyle").
      child: GoldIcon(icon, size: size),
    );
    // Nefes alma (pulse) animasyonu KALDIRILDI (kullanıcı 2026-06-15: "tüm
    // ikonlardan nefes alıp verme animasyonunu kaldır, sabit olsun, animasyon 0")
    // → statik rozet. [index] artık kullanılmıyor (çağıranlar yine geçebilir).
    return badge;
  }
}
