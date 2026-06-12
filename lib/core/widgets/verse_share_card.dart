import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_image.dart';
import 'selaya_logo.dart';

/// A 9:16 branded card designed to be captured and shared as a story
/// (Instagram / WhatsApp / Facebook): photo background, text in front,
/// app logo + name centered at the very bottom.
class VerseShareCard extends StatelessWidget {
  final String? arabic;
  final String text;
  final String reference;
  final String? label;
  final String? backgroundImage;

  const VerseShareCard({
    super.key,
    this.arabic,
    required this.text,
    required this.reference,
    this.label,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // background photo (asset path OR CDN url — .cdn handles both so panel /
        // wallpaper backgrounds render too)
        AppImage.cdn(
          backgroundImage ?? 'assets/images/inspiration_2.jpg',
          fit: BoxFit.cover,
          fallbackColors: const [Color(0xFF13182B), Color(0xFF05070D)],
        ),
        // legibility overlay (darker at top & bottom)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xD905070D), Color(0x7305070D), Color(0xF205070D)],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        Padding(
          // Wider side margins; no header label (removed for a minimal layout).
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
          child: Column(
            children: [
              // Verse block — centered, and auto-scaled so even long passages
              // (e.g. Kadir Gecesi) always fit instead of being clipped.
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: constraints.maxWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (arabic != null && arabic!.isNotEmpty) ...[
                              Text(
                                arabic!,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: AppTypography.arabic(
                                    fontSize: 24,
                                    color: Colors.white,
                                    height: 1.95),
                              ),
                              const Gap.xl(),
                            ],
                            Text(
                              '"$text"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  height: 1.55,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(blurRadius: 12, color: Colors.black54)
                                  ]),
                            ),
                            const Gap.lg(),
                            // surah reference — small + minimal, well clear of
                            // the logo below.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 13, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.16),
                                borderRadius: AppRadius.rSm,
                                border: Border.all(
                                    color: AppColors.gold.withValues(alpha: 0.4)),
                              ),
                              child: Text(reference,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.goldBright,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
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
