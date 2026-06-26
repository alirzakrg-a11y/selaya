import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/geometric_background.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_logo.dart';

class _Feature {
  final IconData icon;
  final String titleKey;
  final String descKey;
  const _Feature(this.icon, this.titleKey, this.descKey);
}

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  static const _features = [
    _Feature(AppIcons.times, 'intro.f1Title', 'intro.f1Desc'),
    _Feature(AppIcons.quran, 'intro.f2Title', 'intro.f2Desc'),
    _Feature(AppIcons.qibla, 'intro.f3Title', 'intro.f3Desc'),
    _Feature(AppIcons.sparkles, 'intro.f4Title', 'intro.f4Desc'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: GeometricBackground(
        patternOpacity: 0.06,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: AppSpacing.screen,
                  children: [
                    const Gap.xl(),
                    // Hero — logo, nabız gibi atan altın hale içinde.
                    SizedBox(
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 232,
                            height: 232,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  c.gold.withValues(alpha: 0.30),
                                  c.gold.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          )
                              .animate(
                                  onPlay: (ctrl) => ctrl.repeat(reverse: true))
                              .scaleXY(
                                  begin: 0.9,
                                  end: 1.08,
                                  duration: 2400.ms,
                                  curve: Curves.easeInOut),
                          const SelayaLogo(size: 134)
                              .animate()
                              .fadeIn(duration: 700.ms)
                              .scale(
                                  begin: const Offset(0.82, 0.82),
                                  curve: Curves.easeOutBack),
                        ],
                      ),
                    ),
                    const Gap.lg(),
                    // Hoş geldiniz — altın gradyan başlık.
                    Center(
                      child: ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          colors: [Color(0xFFF3CD7A), Color(0xFFD4AF6E)],
                        ).createShader(r),
                        child: Text(
                          'intro.welcome'.tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3),
                        ),
                      ),
                    ).animate().fadeIn(delay: 220.ms, duration: 500.ms),
                    const Gap.xs(),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        child: Text(
                          'intro.tagline'.tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: c.textSecondary, height: 1.4),
                        ),
                      ),
                    ).animate().fadeIn(delay: 340.ms, duration: 500.ms),
                    const Gap.xl(),
                    for (var i = 0; i < _features.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: SelayaCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      c.gold.withValues(alpha: 0.24),
                                      c.gold.withValues(alpha: 0.07),
                                    ],
                                  ),
                                ),
                                child: Icon(_features[i].icon,
                                    color: c.gold, size: 22),
                              ),
                              const Gap.md(),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_features[i].titleKey.tr(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700)),
                                    const Gap.xxs(),
                                    Text(_features[i].descKey.tr(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: c.textTertiary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(delay: (460 + 110 * i).ms, duration: 420.ms)
                            .slideX(begin: 0.10, end: 0, curve: Curves.easeOut),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: GradientButton(
                  label: 'intro.start'.tr(),
                  icon: AppIcons.forward,
                  expand: true,
                  onPressed: () => Navigator.of(context).canPop()
                      ? context.pop()
                      : context.go(Routes.onboarding),
                )
                    .animate()
                    .fadeIn(delay: 900.ms, duration: 500.ms)
                    .slideY(begin: 0.3, end: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
