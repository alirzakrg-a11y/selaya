import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/content_providers.dart';
import '../../../../core/localization/localized_text.dart';
import '../../../../core/models/content.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_image.dart';
import '../../data/prayer_repository.dart';

/// Sayaç kartı arka planı için OTURUM başına SABİT rastgele seed → her uygulama
/// açılışında FARKLI tek görsel; rebuild'lerde DEĞİŞMEZ (geçiş/titreme yok).
final _heroBgSeedProvider = Provider<int>((ref) => Random().nextInt(1 << 30));

/// Large hero card: city, date, hijri date, next prayer + live countdown + progress.
class NextPrayerCard extends ConsumerWidget {
  const NextPrayerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    // Büyük fontta (1.3x) içerik taşmasın diye kart YÜKSEKLİĞİ metin ölçeğiyle
    // büyür (öne-çıkanlar gridindeki "/ scale" tekniğiyle aynı). (kullanıcı 2026-06-17)
    final scale = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.35).toDouble();
    final viewAsync = ref.watch(prayerViewProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    // Arka plan: her açılışta duvar kâğıtlarımızdan SABİT rastgele tek görsel
    // (video KALDIRILDI — kullanıcı 2026-06-15).
    final wps = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];
    final imgs = [for (final w in wps) w.image];
    final heroBg = imgs.isEmpty
        ? ''
        : imgs[ref.watch(_heroBgSeedProvider) % imgs.length];

    return AspectRatio(
      // Kompakt: üst/alt boşluk azaltıldı + içerik ortalandı (kullanıcı 2026-06-18).
      aspectRatio: 16 / (8.8 * scale),
      child: ClipRRect(
        borderRadius: AppRadius.rXl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video arka plan KALDIRILDI (kullanıcı 2026-06-15): her açılışta
            // duvar kâğıtlarımızdan SABİT rastgele tek görsel (statik, geçiş yok).
            heroBg.isEmpty
                ? Image.asset(
                    'assets/images/hero_mosque.jpg',
                    fit: BoxFit.cover,
                  )
                : AppImage.cdn(heroBg, fit: BoxFit.cover, memWidth: 720),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xCC05070D),
                    Color(0x6605070D),
                    Color(0xEE05070D),
                  ],
                ),
              ),
            ),
            viewAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                ),
              ),
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
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            AppIcons.location,
                            size: 16,
                            color: AppColors.goldBright,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              v.city.name(lang),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            formatHijri(
                              now,
                              lang,
                              offsetDays: ref.watch(hijriOffsetProvider),
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                      Text(
                        formatGregorian(now, lang),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: Colors.white60),
                      ),
                      const Spacer(),
                      Text(
                        '${'home.nextPrayer'.tr()} • ${v.nextSlot.labelKey.tr()}',
                        style: const TextStyle(
                          color: AppColors.goldBright,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          formatCountdown(remaining),
                          style: AppTypography.countdown(
                            Colors.white,
                            fontSize: 46,
                          ),
                        ),
                      ),
                      const Gap.sm(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            v.nextSlot.icon,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              '${v.nextSlot.labelKey.tr()}  ${formatClock(v.nextTime)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap.sm(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.gold,
                          ),
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
