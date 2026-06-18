import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Altın GRADYANLI ikon — glyph'i ışıltılı→koyu altın metalik gradyanla boyar
/// (mockup'taki premium gold hissi). Tema paletinin `goldGradient`'ini kullanır;
/// koyu yeşilde ışıltılı altın, açık temada koyu altın gradyanı olur.
class GoldIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final List<Color>? gradient;
  const GoldIcon(this.icon, {super.key, this.size = 24, this.gradient});

  @override
  Widget build(BuildContext context) {
    final colors = gradient ?? context.colors.goldGradient;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}
