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

  const GreetingCard({
    super.key,
    required this.message,
    this.occasionLabel,
    required this.backgroundImage,
    this.fontFamily,
    this.fontScale = 1.0,
    this.lineHeight = 1.55,
  });

  TextStyle _msgStyle() {
    final base = TextStyle(
      color: Colors.white,
      fontSize: 22 * fontScale,
      height: lineHeight,
      fontWeight: FontWeight.w600,
      shadows: const [Shadow(blurRadius: 12, color: Colors.black54)],
    );
    if (fontFamily == null || fontFamily!.isEmpty) return base;
    return GoogleFonts.getFont(fontFamily!, textStyle: base);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppImage.cdn(
          backgroundImage,
          fit: BoxFit.cover,
          fallbackColors: const [Color(0xFF13182B), Color(0xFF05070D)],
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xD905070D), Color(0x6605070D), Color(0xF205070D)],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
          child: Column(
            children: [
              if (occasionLabel != null && occasionLabel!.isNotEmpty) ...[
                const Gap.sm(),
                Text(occasionLabel!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.goldBright,
                        letterSpacing: 2.5,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
              // Auto-scaled so long greetings always fit instead of clipping.
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: constraints.maxWidth),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: _msgStyle(),
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
