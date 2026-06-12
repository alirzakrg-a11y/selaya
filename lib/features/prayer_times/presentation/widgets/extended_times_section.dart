import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/selaya_card.dart';
import '../../data/prayer_repository.dart';
import '../../domain/extended_times.dart';

/// Collapsible list of the optional/extended prayer times (İşrak, Kuşluk,
/// Evvabin, night thirds, Seher).
class ExtendedTimesSection extends ConsumerWidget {
  const ExtendedTimesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ext = ref.watch(extendedTimesProvider).value;
    if (ext == null) return const SizedBox.shrink();
    final segments = ext.segments.where((s) => s.isValid).toList();
    if (segments.isEmpty) return const SizedBox.shrink();

    return SelayaCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.base, 0, AppSpacing.base, AppSpacing.md),
          leading: Icon(AppIcons.sparkles, color: c.gold, size: 20),
          title: Text('prayer.extendedTimes'.tr(),
              style: Theme.of(context).textTheme.titleSmall),
          iconColor: c.gold,
          collapsedIconColor: c.textTertiary,
          children: [for (final s in segments) _row(context, s)],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ExtTime s) {
    final c = context.colors;
    final value = s.end == null
        ? formatClock(s.start)
        : '${formatClock(s.start)} – ${formatClock(s.end!)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(s.labelKey.tr(),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.textSecondary)),
          ),
          Text(value,
              style: AppTypography.tabular(Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(color: c.textPrimary))),
        ],
      ),
    );
  }
}
