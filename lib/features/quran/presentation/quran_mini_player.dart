import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/instant_swipe.dart';
import '../data/quran_audio_controller.dart';
import 'quran_now_playing.dart';

/// Alt sabit mini-player — Kuran/Yâsîn sesli okuması çalarken görünür (sesli
/// hikâyelerdeki gibi). Sadece "quran" modunda; başka bir şey çalarken gizlenir.
/// Dokununca o sureyi okuyucuda açar; arka plan + bildirim kumandası handler'dan.
class QuranMiniPlayer extends ConsumerWidget {
  const QuranMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(quranAudioControllerProvider);
    final ctrl = ref.read(quranAudioControllerProvider.notifier);
    if (st.surahNumber == null || !ctrl.isQuranMode) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    // Yukarı kaydır → tam ekran; ANINDA tepki (parmak kalkmasını beklemez).
    return InstantSwipe(
      onUp: () => openQuranNowPlaying(context),
      child: GestureDetector(
      onTap: () => openQuranNowPlaying(context),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // İnce İLERLEME çizgisi — çalan ayetin konumu (tam genişlik).
            StreamBuilder<Duration?>(
              stream: ctrl.durationStream,
              builder: (context, dSnap) {
                final total = dSnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: ctrl.positionStream,
                  builder: (context, pSnap) {
                    final pos = pSnap.data ?? Duration.zero;
                    final f = total.inMilliseconds == 0
                        ? 0.0
                        : (pos.inMilliseconds / total.inMilliseconds)
                            .clamp(0.0, 1.0);
                    return SizedBox(
                      height: 3,
                      width: double.infinity,
                      child: ColoredBox(
                        color: c.border.withValues(alpha: 0.5),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: f,
                          child: ColoredBox(color: c.gold),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base, 0, AppSpacing.sm, AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            // ② "Yukarı çek" ipucu (statik ok). Zıplama animasyonu KALDIRILDI:
            // repeat'li ticker mini görünürken uygulamayı kesintisiz 60fps
            // çizime zorluyordu — navbar blur'uyla birlikte cihazda/emülatörde
            // sürekli jank ("donma/yavaşlık") üretiyordu (profile kanıtlı).
            SizedBox(
              height: 14,
              child: Icon(Icons.keyboard_arrow_up_rounded,
                  size: 22, color: c.textTertiary),
            ),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ctrl.art.isNotEmpty
                      ? AppImage.cdn(ctrl.art,
                          width: 42, height: 42, fit: BoxFit.cover)
                      : Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.gold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(AppIcons.quran, color: c.gold, size: 22),
                        ),
                ),
                const Gap.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(st.surahName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall),
                      // Canlı "kaçıncı ayet" satırı: parça değiştikçe günceller.
                      StreamBuilder<int?>(
                        stream: ctrl.currentIndexStream,
                        builder: (context, _) {
                          final a = ctrl.currentAyahNumber;
                          final tr = context.langCode == 'tr';
                          final sub = st.loading
                              ? 'common.loading'.tr()
                              : a == null
                                  ? 'quran.title'.tr()
                                  : (tr ? '$a. ayet okunuyor' : 'Verse $a');
                          return Text(sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: c.textTertiary));
                        },
                      ),
                    ],
                  ),
                ),
                // ⏮ Önceki ayet (kuyruk başındaysa önceki sure).
                IconButton(
                  iconSize: 26,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  color: c.textSecondary,
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: ctrl.previous,
                ),
                IconButton(
                  iconSize: 36,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  color: c.gold,
                  icon: Icon(st.playing
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded),
                  onPressed: ctrl.toggle,
                ),
                // ⏭ Sıradaki ayet (kuyruk sonundaysa sıradaki sure).
                IconButton(
                  iconSize: 26,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  color: c.textSecondary,
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: ctrl.next,
                ),
                IconButton(
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  color: c.textTertiary,
                  icon: const Icon(Icons.stop_circle_outlined),
                  onPressed: ctrl.stop,
                ),
              ],
            ),
          ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
