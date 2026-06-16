import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/selaya_card.dart';
import '../../data/prayer_repository.dart';
import '../../domain/prayer.dart';

/// Compact horizontal strip of the six daily slots with the active one highlighted.
class PrayerStrip extends ConsumerWidget {
  const PrayerStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final times = ref.watch(dailyTimesProvider);
    final view = ref.watch(prayerViewProvider).value;

    return times.when(
      loading: () => const SizedBox(height: 92),
      error: (_, _) => const SizedBox.shrink(),
      data: (t) {
        final active = view?.currentSlot;
        return SelayaCard(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md, horizontal: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Açılışta vakitler soldan sağa tek tek belirir (hafif yukarı
              // kayarak) — kısa, bir kerelik giriş animasyonu.
              for (var i = 0; i < PrayerSlot.values.length; i++)
                _SlotCell(
                  slot: PrayerSlot.values[i],
                  time: t.timeOf(PrayerSlot.values[i]),
                  active: PrayerSlot.values[i] == active,
                )
                    .animate(delay: (60 * i).ms)
                    .fadeIn(duration: 320.ms, curve: Curves.easeOut)
                    .moveY(begin: 10, end: 0, curve: Curves.easeOutCubic),
            ],
          ),
        );
      },
    );
  }
}

class _SlotCell extends StatelessWidget {
  final PrayerSlot slot;
  final DateTime time;
  final bool active;
  const _SlotCell({required this.slot, required this.time, required this.active});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: AppRadius.rMd,
        gradient: active ? LinearGradient(colors: c.prayerActive) : null,
        border: active ? Border.all(color: c.gold.withValues(alpha: 0.5)) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aktif ikon nabzı KALDIRILDI (kullanıcı 2026-06-15 "ikonlarda nefes
          // alma olmasın") — statik; aktif vakit yine parlak altın renkle ayrışır.
          Icon(slot.icon,
              size: 24, color: active ? c.goldBright : c.textTertiary),
          const SizedBox(height: 6),
          Text(
            slot.labelKey.tr(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: active ? c.goldBright : c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            formatClock(time),
            style: AppTypography.tabular(
              Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: active ? Colors.white : c.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
