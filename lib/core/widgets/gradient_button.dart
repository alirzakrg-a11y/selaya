import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Primary gold-gradient CTA button.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final EdgeInsetsGeometry padding;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.padding = const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl, vertical: AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final onGold = c.isDark ? const Color(0xFF1A1203) : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.rLg,
        gradient: LinearGradient(colors: c.goldGradient),
        boxShadow: [
          BoxShadow(
            color: c.gold.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.rLg,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.rLg,
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: onGold),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: onGold, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary "ghost" button (outlined, transparent).
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.rLg,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.rLg,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.rLg,
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: c.textPrimary),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
