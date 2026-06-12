import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    return Icon(AppIcons.aiMagic, size: size, color: col)
        .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
        .scaleXY(
            begin: 0.9, end: 1.15, duration: 1300.ms, curve: Curves.easeInOut)
        .rotate(
            begin: -0.05, end: 0.05, duration: 1300.ms, curve: Curves.easeInOut)
        .shimmer(duration: 1300.ms, color: Colors.white);
  }
}
