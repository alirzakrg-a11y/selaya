import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_image.dart';
import 'selaya_logo.dart';

/// A 9:16 branded greeting card (Cuma/Bayram/Ramazan/Kandil…) — photo
/// background, the (editable) message in front, app logo + slogan at the bottom.
/// Mirrors [VerseShareCard]'s structure so the share pipeline is identical.
class GreetingCard extends StatelessWidget {
  final String message;
  final String? occasionLabel;
  final String backgroundImage;
  final String? fontFamily;
  final double fontScale;
  final double lineHeight;
  final Color textColor;
  final TextAlign textAlign;
  final bool framed;
  final double overlayStrength; // fotoğraf üstü karartma çarpanı (0.4–1.5)
  final Alignment textAnchor; // Canva-tarzı hazır konum (orta/üst/alt/köşe)
  final Offset textNudge; // sürükleme ile eklenen ince ayar (kart genişlik/
  // yüksekliğinin oranı olarak normalize — klavye açılıp kart küçülünce de
  // doğru yerde kalsın diye MUTLAK PİKSEL DEĞİL).

  const GreetingCard({
    super.key,
    required this.message,
    this.occasionLabel,
    required this.backgroundImage,
    this.fontFamily,
    this.fontScale = 1.0,
    this.lineHeight = 1.55,
    this.textColor = Colors.white,
    this.textAlign = TextAlign.center,
    this.framed = false,
    this.overlayStrength = 1.0,
    this.textAnchor = Alignment.center,
    this.textNudge = Offset.zero,
  });

  TextStyle _msgStyle() {
    // Metin açık renk → koyu gölge; koyu renk → açık gölge (her zeminde okunur).
    final glow =
        textColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white60;
    final base = TextStyle(
      color: textColor,
      fontSize: 22 * fontScale,
      height: lineHeight,
      fontWeight: FontWeight.w600,
      shadows: [Shadow(blurRadius: 12, color: glow)],
    );
    if (fontFamily == null || fontFamily!.isEmpty) return base;
    return GoogleFonts.getFont(fontFamily!, textStyle: base);
  }

  // Karartma gradyanının her durağını [overlayStrength] ile ölçekle.
  Color _scrim(int alpha) => Color.fromARGB(
      (alpha * overlayStrength).clamp(0, 255).round(), 5, 7, 13);

  @override
  Widget build(BuildContext context) {
    final crossAlign = switch (textAlign) {
      TextAlign.left || TextAlign.start => CrossAxisAlignment.start,
      TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        AppImage.cdn(
          backgroundImage,
          fit: BoxFit.cover,
          fallbackColors: const [Color(0xFF13182B), Color(0xFF05070D)],
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_scrim(0xD9), _scrim(0x66), _scrim(0xF2)],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
        // Zarif altın çerçeve (isteğe bağlı) — köşe süsü hissi veren ince kenar.
        if (framed)
          Padding(
            padding: const EdgeInsets.all(14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.goldBright.withValues(alpha: 0.75),
                    width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: crossAlign,
            children: [
              if (occasionLabel != null && occasionLabel!.isNotEmpty) ...[
                const Gap.sm(),
                Text(occasionLabel!.toUpperCase(),
                    textAlign: textAlign,
                    style: const TextStyle(
                        color: AppColors.goldBright,
                        letterSpacing: 2.5,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
              // Auto-scaled so long greetings always fit instead of clipping.
              // Align = Canva-tarzı hazır konum (üst/orta/alt/köşe); Transform.
              // translate = kullanıcının kart üzerinde sürükleyerek eklediği
              // ince ayar (normalize offset → constraints boyutuna göre ölçekli).
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: textAnchor,
                    child: Transform.translate(
                      offset: Offset(
                        textNudge.dx * constraints.maxWidth,
                        textNudge.dy * constraints.maxHeight,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * 0.94),
                          child: Text(
                            message,
                            textAlign: textAlign,
                            style: _msgStyle(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Spacing then the brand mark (icon + SELAYA), smaller. No slogan.
              const Gap.xl(),
              const SelayaLogo(size: 42),
              const Gap.md(),
            ],
          ),
        ),
      ],
    );
  }
}
