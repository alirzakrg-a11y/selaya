import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';

/// "Title ........ See all ›" row used above home/list sections.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final String? actionLabel;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    actionLabel ?? 'common.seeAll'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: c.gold),
                  ),
                  Icon(AppIcons.forward, size: 16, color: c.gold),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
