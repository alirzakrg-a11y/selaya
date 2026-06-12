import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/geometric_background.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_logo.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _yearly = true;

  static const _features = [
    (AppIcons.close, 'premium.featureAdfree'),
    (AppIcons.moon, 'premium.featureThemes'),
    (AppIcons.wallpaper, 'premium.featureWidgets'),
    (AppIcons.aiChat, 'premium.featureAi'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: GeometricBackground(
        glowColor: AppColors.gold,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(AppIcons.close, color: c.textPrimary),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: AppSpacing.screen,
                  children: [
                    const Gap.md(),
                    Center(child: const SelayaLogo(size: 64, showWordmark: false)),
                    const Gap.md(),
                    Center(
                      child: ShaderMask(
                        shaderCallback: (r) =>
                            const LinearGradient(colors: AppColors.goldGradient)
                                .createShader(r),
                        child: Text('premium.title'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(color: Colors.white)),
                      ),
                    ),
                    const Gap.xs(),
                    Center(
                      child: Text('premium.subtitle'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: c.textSecondary)),
                    ),
                    const Gap.xl(),
                    SelayaCard(
                      child: Column(
                        children: [
                          for (final f in _features)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: c.gold.withValues(alpha: 0.14),
                                    ),
                                    child: Icon(f.$1, color: c.gold, size: 18),
                                  ),
                                  const Gap.md(),
                                  Expanded(
                                      child: Text(f.$2.tr(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall)),
                                  Icon(AppIcons.checkCircle, color: c.success, size: 20),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Gap.lg(),
                    _PlanTile(
                      label: 'premium.yearly'.tr(),
                      price: '₺499,99',
                      per: 'premium.perYear'.tr(),
                      badge: 'premium.bestValue'.tr(),
                      selected: _yearly,
                      onTap: () => setState(() => _yearly = true),
                    ),
                    const Gap.sm(),
                    _PlanTile(
                      label: 'premium.monthly'.tr(),
                      price: '₺69,99',
                      per: 'premium.perMonth'.tr(),
                      selected: !_yearly,
                      onTap: () => setState(() => _yearly = false),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: AppSpacing.screen,
                child: Column(
                  children: [
                    GradientButton(
                      label: 'premium.subscribe'.tr(),
                      icon: AppIcons.crown,
                      expand: true,
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('common.comingSoon'.tr())),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text('premium.restore'.tr(),
                          style: TextStyle(color: c.textTertiary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String label;
  final String price;
  final String per;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;
  const _PlanTile({
    required this.label,
    required this.price,
    required this.per,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: selected ? c.gold.withValues(alpha: 0.12) : c.surfaceAlt,
          borderRadius: AppRadius.rLg,
          border: Border.all(
              color: selected ? c.gold : c.border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(selected ? AppIcons.checkCircle : Icons.circle_outlined,
                color: selected ? c.gold : c.textTertiary),
            const Gap.md(),
            Expanded(
              child: Row(
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  if (badge != null) ...[
                    const Gap.sm(),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: c.gold, borderRadius: AppRadius.rSm),
                      child: Text(badge!,
                          style: const TextStyle(
                              color: Color(0xFF1A1203),
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: Theme.of(context).textTheme.titleMedium),
                Text(per,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: c.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
