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
    _Feature(AppIcons.aiChat, 'intro.f5Title', 'intro.f5Desc'),
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
                    const Center(child: SelayaLogo(size: 124))
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .scale(begin: const Offset(0.9, 0.9)),
                    const Gap.lg(),
                    Center(
                      child: Text('intro.welcome'.tr(),
                          style: Theme.of(context).textTheme.headlineMedium),
                    ),
                    const Gap.xs(),
                    Center(
                      child: Text('intro.tagline'.tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: c.textSecondary)),
                    ),
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
                                  color: c.gold.withValues(alpha: 0.13),
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
                                            .titleSmall),
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
                            .fadeIn(delay: (120 * i).ms, duration: 400.ms)
                            .slideX(begin: 0.08, end: 0),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
