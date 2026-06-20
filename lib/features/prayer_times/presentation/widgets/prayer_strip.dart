import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gold_icon.dart';
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
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Açılışta vakitler soldan sağa tek tek belirir (hafif yukarı
              // kayarak) — kısa, bir kerelik giriş animasyonu. Her hücre Expanded:
              // büyük fontta (1.3x) 6 vakit yan yana TAŞMASIN (eşit pay; içi küçülür).
              for (var i = 0; i < PrayerSlot.values.length; i++)
                Expanded(
                  child:
                      _SlotCell(
                            slot: PrayerSlot.values[i],
                            time: t.timeOf(PrayerSlot.values[i]),
                            active: PrayerSlot.values[i] == active,
                          )
                          .animate(delay: (60 * i).ms)
                          .fadeIn(duration: 320.ms, curve: Curves.easeOut)
                          .moveY(begin: 10, end: 0, curve: Curves.easeOutCubic),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SlotCell extends StatelessWidget {
  /// Aktif vakit hücresinin altın çerçevesinin opaklığı (yarı saydam).
  static const double activeBorderAlpha = 0.5;

  final PrayerSlot slot;
  final DateTime time;
  final bool active;
  const _SlotCell({
    required this.slot,
    required this.time,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.rMd,
        gradient: active ? LinearGradient(colors: c.prayerActive) : null,
        border: active
            ? Border.all(color: c.gold.withValues(alpha: activeBorderAlpha))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tüm vakit ikonları GRADYANLI altın (kullanıcı 2026-06-18: "imsaktakilerin
          // logolarını da"); aktif vakit pill zemin + altın çerçeve + beyaz saatle ayrışır.
          GoldIcon(slot.icon, size: 24),
          const SizedBox(height: 6),
          // FittedBox: büyük fontta hücreye sığmazsa metni küçültür (taşma yok).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              slot.labelKey.tr(),
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active ? c.goldBright : c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatClock(time),
              maxLines: 1,
              style: AppTypography.tabular(
                Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: active ? Colors.white : c.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
