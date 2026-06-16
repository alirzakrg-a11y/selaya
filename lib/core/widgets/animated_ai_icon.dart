import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Bol animasyonlu SELAYA AI ikonu — sürekli nabız (scale) + hafif salınım
/// (rotate) + ışıltı (shimmer). SELAYA AI'nın bulunduğu her yerde (sohbet
/// başlığı, kartlar) canlı, "yapay zekâ" hissi veren bir ikon sunar.
class AnimatedAiIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const AnimatedAiIcon({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final col = color ?? context.colors.gold;
    // Animasyon (nabız/salınım/ışıltı) KALDIRILDI (kullanıcı 2026-06-15) → statik.
    return Icon(AppIcons.aiMagic, size: size, color: col);
  }
}
