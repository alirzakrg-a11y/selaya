import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// SELAYA AI ikonu. ÖNCEDEN sürekli nabız + salınım + shimmer (sonsuz repeat)
/// idi; flutter_animate ticker'ı widget yok olunca sızıp SONSUZA dek tick
/// atıyordu — "Daha Fazla" listesindeki bu ikon ana Dart thread'ini görünmez
/// kare olmadan yakıyor + her gezinmede birikiyordu (donmanın kaynaklarından).
///
/// Artık TEK-SEFERLİK "pop-in" (belirince hafif büyüyüp belirir, sonra STATİK)
/// → tick birikmez, motor boşa düşer.
class AnimatedAiIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const AnimatedAiIcon({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final col = color ?? context.colors.gold;
    return Icon(AppIcons.aiMagic, size: size, color: col)
        .animate()
        .fadeIn(duration: 250.ms)
        .scaleXY(begin: 0.8, end: 1.0, duration: 320.ms, curve: Curves.easeOutBack);
  }
}
