import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/localized_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/video_background.dart';
import '../../data/prayer_repository.dart';

/// Large hero card: city, date, hijri date, next prayer + live countdown + progress.
class NextPrayerCard extends ConsumerWidget {
  const NextPrayerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final viewAsync = ref.watch(prayerViewProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    return AspectRatio(
      // Kompakt: üst/alt boşluk azaltıldı (kullanıcı isteği).
      aspectRatio: 16 / 9.6,
      child: ClipRRect(
        borderRadius: AppRadius.rXl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const VideoBackground(
                fallbackImage: 'assets/images/hero_mosque.jpg'),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xCC05070D), Color(0x6605070D), Color(0xEE05070D)],
                ),
              ),
            ),
            viewAsync.when(
              loading: () => const Center(
                  child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold))),
              error: (_, _) => const SizedBox.shrink(),
              data: (v) {
                var remaining = v.remaining(now);
                // ⑥ Sonraki vakit GEÇTİYSE görünüm bayatlamıştır (provider
                // nextTime'ı saniyede bir değil, yalnız şehir/yöntem değişince
                // hesaplar) → yeniden hesapla ki sayaç bir sonraki vakte geçsin;
                // bu arada negatife düşüp "00:00 / donuk" görünmesin diye 0'a
                // sıkıştırılır. Düzelince remaining tekrar pozitif olur (döngü yok).
                if (remaining.isNegative) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) ref.invalidate(prayerViewProvider);
                  });
                  remaining = Duration.zero;
                }
                final progress = v.progress(now);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(AppIcons.location,
                              size: 16, color: AppColors.goldBright),
                          const SizedBox(width: 4),
                          Text(
                            v.city.name(lang),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            formatHijri(now, lang,
                                offsetDays: ref.watch(hijriOffsetProvider)),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      Text(
                        formatGregorian(now, lang),
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '${'home.nextPrayer'.tr()} • ${v.nextSlot.labelKey.tr()}',
                        style: const TextStyle(
                            color: AppColors.goldBright,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatCountdown(remaining),
                        style: AppTypography.countdown(Colors.white, fontSize: 46),
                      ),
                      const Gap.sm(),
                      Row(
                        children: [
                          Icon(v.nextSlot.icon, size: 16, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            '${v.nextSlot.labelKey.tr()}  ${formatClock(v.nextTime)}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Gap.sm(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
