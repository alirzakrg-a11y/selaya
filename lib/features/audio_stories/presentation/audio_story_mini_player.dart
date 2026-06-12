import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/instant_swipe.dart';
import '../data/audio_story_controller.dart';
import 'audio_story_now_playing.dart';

/// Alt sabit mini-player — sesli hikâye çalarken görünür (radyodaki gibi).
/// Sadece "story" modunda görünür; radyo çalarken gizlenir.
class AudioStoryMiniPlayer extends ConsumerWidget {
  const AudioStoryMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(audioStoryControllerProvider);
    final ctrl = ref.read(audioStoryControllerProvider.notifier);
    if (st.current == null || !ctrl.isStoryMode) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    final lang = context.langCode;
    final cat = st.current!;

    // Yukarı kaydır → tam ekran; ANINDA tepki (parmak kalkmasını beklemez).
    return InstantSwipe(
      onUp: () => openAudioStoryNowPlaying(context),
      child: GestureDetector(
      onTap: () => openAudioStoryNowPlaying(context),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // İnce İLERLEME çizgisi — çalan bölümün konumu (tam genişlik).
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
                  AppSpacing.base, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
              child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AppImage.cdn(cat.cover,
                  width: 42, height: 42, fit: BoxFit.cover),
            ),
            const Gap.md(),
            Expanded(
              child: StreamBuilder<int?>(
                stream: ctrl.currentIndexStream,
                builder: (context, snap) {
                  final i = (snap.data ?? ctrl.currentIndex)
                      .clamp(0, cat.episodes.length - 1);
                  final ep = cat.episodes[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(ep.title(lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                          st.loading ? 'common.loading'.tr() : cat.title(lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: c.textTertiary)),
                    ],
                  );
                },
              ),
            ),
            IconButton(
              iconSize: 38,
              color: c.gold,
              icon: Icon(st.playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded),
              onPressed: ctrl.toggle,
            ),
            IconButton(
              color: c.textSecondary,
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: ctrl.stop,
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
