import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../data/weather_service.dart';

/// Compact home weather card: today (large) + the next three days. Silently
/// hides itself if the forecast can't be fetched (offline), so it never breaks
/// the home screen.
class WeatherStrip extends ConsumerWidget {
  const WeatherStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weatherForecastProvider);
    return async.when(
      loading: () => const _WeatherSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (days) {
        if (days.isEmpty) return const SizedBox.shrink();
        final c = context.colors;
        final lang = context.langCode;
        final today = days.first;
        return SelayaCard(
          child: Row(
            children: [
              Icon(today.icon, color: c.gold, size: 36),
              const Gap.md(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${today.tMax.round()}°',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(today.labelKey().tr(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textSecondary)),
                ],
              ),
              const Spacer(),
              for (final d in days.skip(1).take(3))
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.base),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DateFormat('E', lang).format(d.date),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: c.textTertiary)),
                      const Gap.xs(),
                      Icon(d.icon, color: c.textSecondary, size: 18),
                      const Gap.xs(),
                      Text('${d.tMax.round()}°',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WeatherSkeleton extends StatelessWidget {
  const _WeatherSkeleton();
  @override
  Widget build(BuildContext context) => SelayaCard(
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Icon(Icons.cloud_rounded,
                  color: context.colors.textTertiary, size: 30),
              const Gap.md(),
              Text('—',
                  style: TextStyle(color: context.colors.textTertiary)),
            ],
          ),
        ),
      );
}
