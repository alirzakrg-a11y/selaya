import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import 'gradient_button.dart';

class SelayaLoading extends StatelessWidget {
  const SelayaLoading({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(context.colors.gold),
          ),
        ),
      );
}

class SelayaError extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  const SelayaError({super.key, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.info, color: c.danger, size: 40),
            const Gap.base(),
            Text('common.error'.tr(),
                style: Theme.of(context).textTheme.titleMedium),
            if (onRetry != null) ...[
              const Gap.base(),
              GhostButton(
                  label: 'common.retry'.tr(),
                  icon: AppIcons.refresh,
                  onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

class SelayaEmpty extends StatelessWidget {
  final String? message;
  final IconData? icon;
  const SelayaEmpty({super.key, this.message, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? AppIcons.sparkles, color: c.textTertiary, size: 38),
          const Gap.md(),
          Text(message ?? 'common.empty'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textTertiary)),
        ],
      ),
    );
  }
}
