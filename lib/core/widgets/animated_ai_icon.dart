import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// SELAYA AI ikonu — STATİK (animasyonsuz). Kullanıcı isteği: eski telefonlarda
/// akıcılık için tüm dekoratif animasyonlar kaldırıldı. (Adı tarihsel; artık
/// animasyon yok.)
class AnimatedAiIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const AnimatedAiIcon({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final col = color ?? context.colors.gold;
    return Icon(AppIcons.aiMagic, size: size, color: col);
  }
}
