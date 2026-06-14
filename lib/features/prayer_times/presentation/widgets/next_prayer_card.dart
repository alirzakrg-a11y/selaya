import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/localized_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/data/content_providers.dart';
import '../../../../core/models/content.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rotating_image_background.dart';
import '../../data/prayer_repository.dart';
import '../../domain/prayer.dart';

/// Large hero card: city, date, hijri date, next prayer + live countdown + progress.
///
/// PERF: [clockProvider] (saniyelik tik) yalnızca tarih satırları ve sayaç
/// bloğu gibi KÜÇÜK alt widget'larda izlenir — eskiden kartın tamamı her
/// saniye yeniden kuruluyordu. Sayaç bloğu RepaintBoundary ile de izole.
class NextPrayerCard extends ConsumerWidget {
  const NextPrayerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final viewAsync = ref.watch(prayerViewProvider);
    // Arka plan: panel/CDN wallpaper'larından ilk 3 ücretsiz görsel (videonun
    // YERİNE — eski telefonlarda sürekli video decode takılma yapıyordu).
    // gridImage = ≤560px hafif önizleme; boşsa hero_mosque.jpg yerel fallback.
    final wps = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];
    final bgImages = [
      for (final w in wps.where((w) => !w.premium).take(3)) w.gridImage,
    ];

    return AspectRatio(
      // Daha kompakt (kullanıcı 2026-06-14 "sayacı küçültebilirsin"): kart
      // alçaltıldı (16/9.6 → 16/8.6) ki ana ekran tek sayfaya yaklaşsın.
      aspectRatio: 16 / 8.6,
      child: ClipRRect(
        borderRadius: AppRadius.rXl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RotatingImageBackground(
              images: bgImages,
              fallback: 'assets/images/hero_mosque.jpg',
            ),
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
              data: (v) => Padding(
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
                        const _HijriDate(),
                      ],
                    ),
                    const _GregorianDate(),
                    const Spacer(),
                    Text(
                      '${'home.nextPrayer'.tr()} • ${v.nextSlot.labelKey.tr()}',
                      style: const TextStyle(
                          color: AppColors.goldBright,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    _CountdownAndProgress(v: v),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saniyelik saatten yalnız bu küçük metin etkilenir (hicri tarih).
class _HijriDate extends ConsumerWidget {
  const _HijriDate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    return Text(
      formatHijri(now, context.langCode,
          offsetDays: ref.watch(hijriOffsetProvider)),
      style: const TextStyle(color: Colors.white70, fontSize: 12),
    );
  }
}

/// Saniyelik saatten yalnız bu küçük metin etkilenir (miladi tarih).
class _GregorianDate extends ConsumerWidget {
  const _GregorianDate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    return Text(
      formatGregorian(now, context.langCode),
      style: const TextStyle(color: Colors.white60, fontSize: 12),
    );
  }
}

/// Canlı geri sayım + ilerleme çubuğu — kartın her saniye değişen TEK bölgesi;
/// RepaintBoundary ile çizimi de izole edilir.
class _CountdownAndProgress extends ConsumerWidget {
  final PrayerView v;
  const _CountdownAndProgress({required this.v});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    var remaining = v.remaining(now);
    // ⑥ Sonraki vakit GEÇTİYSE görünüm bayatlamıştır (provider nextTime'ı
    // saniyede bir değil, yalnız şehir/yöntem değişince hesaplar) → yeniden
    // hesapla ki sayaç bir sonraki vakte geçsin; bu arada negatife düşüp
    // "00:00 / donuk" görünmesin diye 0'a sıkıştırılır.
    if (remaining.isNegative) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ref.invalidate(prayerViewProvider);
      });
      remaining = Duration.zero;
    }
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatCountdown(remaining),
            style: AppTypography.countdown(Colors.white, fontSize: 40),
          ),
          const Gap.xs(),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: v.progress(now),
              minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}
