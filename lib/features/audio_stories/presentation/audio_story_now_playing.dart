import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/mini_player_chrome.dart';
import '../data/audio_story_controller.dart';

/// Sesli hikâye "şimdi çalıyor" ekranı (radyodaki gibi slide-up): kapak +
/// transport + bölümler + aşağıda diğer sesli hikâyeler.
class AudioStoryNowPlaying extends ConsumerWidget {
  const AudioStoryNowPlaying({super.key});

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lang = context.langCode;
    final st = ref.watch(audioStoryControllerProvider);
    final ctrl = ref.read(audioStoryControllerProvider.notifier);
    final cat = st.current;
    if (cat == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: Text('—')),
      );
    }
    final others = (ref.watch(audioStoriesProvider).asData?.value ??
            const <AudioStoryCategory>[])
        .where((x) => x.id != cat.id)
        .toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.7),
            radius: 1.1,
            colors: [c.goldDeep.withValues(alpha: 0.3), c.bg, c.bg],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.stop_circle_outlined),
                      color: c.textSecondary,
                      onPressed: () {
                        ctrl.stop();
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ],
                ),
                StreamBuilder<int?>(
                  stream: ctrl.currentIndexStream,
                  builder: (context, snap) {
                    final i = (snap.data ?? ctrl.currentIndex)
                        .clamp(0, cat.episodes.length - 1);
                    final ep = cat.episodes[i];
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: AppImage.cdn(cat.cover,
                              width: 168, height: 168, fit: BoxFit.cover),
                        ),
                        const Gap.md(),
                        Text(ep.title(lang),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                            ep.subtitle(lang).isNotEmpty
                                ? ep.subtitle(lang)
                                : cat.title(lang),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: c.gold)),
                      ],
                    );
                  },
                ),
                const Gap.sm(),
                _SeekBar(ctrl: ctrl),
                const Gap.xs(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 38,
                      color: c.textSecondary,
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: ctrl.previous,
                    ),
                    const Gap.md(),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            LinearGradient(colors: [c.goldBright, c.goldDeep]),
                      ),
                      child: IconButton(
                        iconSize: 50,
                        color: c.bg,
                        icon: Icon(st.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                        onPressed: ctrl.toggle,
                      ),
                    ),
                    const Gap.md(),
                    IconButton(
                      iconSize: 38,
                      color: c.textSecondary,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: ctrl.next,
                    ),
                  ],
                ),
                const Gap.md(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Bölümler',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: c.textSecondary)),
                      ),
                      const Gap.xs(),
                      StreamBuilder<int?>(
                        stream: ctrl.currentIndexStream,
                        builder: (context, snap) {
                          final cur = (snap.data ?? ctrl.currentIndex)
                              .clamp(0, cat.episodes.length - 1);
                          return Column(
                            children: [
                              for (var i = 0; i < cat.episodes.length; i++)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () => ctrl.jumpTo(i),
                                  leading: Icon(
                                      i == cur
                                          ? Icons.graphic_eq_rounded
                                          : Icons.play_circle_outline_rounded,
                                      color: c.gold),
                                  title: Text(cat.episodes[i].title(lang),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: i == cur
                                              ? c.gold
                                              : c.textPrimary,
                                          fontWeight: i == cur
                                              ? FontWeight.w700
                                              : FontWeight.w500)),
                                  subtitle: cat.episodes[i]
                                          .subtitle(lang)
                                          .isNotEmpty
                                      ? Text(cat.episodes[i].subtitle(lang),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)
                                      : null,
                                  trailing: cat.episodes[i].durationSec > 0
                                      ? Text(
                                          _fmt(Duration(
                                              seconds:
                                                  cat.episodes[i].durationSec)),
                                          style: TextStyle(
                                              color: c.textTertiary,
                                              fontSize: 12))
                                      : null,
                                ),
                            ],
                          );
                        },
                      ),
                      if (others.isNotEmpty) ...[
                        const Gap.lg(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Diğer Sesli Hikâyeler',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: c.textSecondary)),
                        ),
                        const Gap.xs(),
                        for (final o in others)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => ctrl.play(o, 0, lang),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppImage.cdn(o.cover,
                                  width: 46, height: 46, fit: BoxFit.cover),
                            ),
                            title: Text(o.title(lang),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${o.episodes.length} bölüm',
                                style: TextStyle(
                                    color: c.textTertiary, fontSize: 12)),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  final AudioStoryController ctrl;
  const _SeekBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StreamBuilder<Duration?>(
      stream: ctrl.durationStream,
      builder: (context, durSnap) {
        final total = durSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: ctrl.positionStream,
          builder: (context, posSnap) {
            var pos = posSnap.data ?? Duration.zero;
            if (pos > total) pos = total;
            final maxMs = total.inMilliseconds.toDouble();
            final value = maxMs <= 0
                ? 0.0
                : pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: c.gold,
                    inactiveTrackColor: c.border,
                    thumbColor: c.gold,
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs <= 0 ? 1 : maxMs,
                    value: value,
                    onChanged: (v) =>
                        ctrl.seek(Duration(milliseconds: v.round())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AudioStoryNowPlaying._fmt(pos),
                          style:
                              TextStyle(color: c.textTertiary, fontSize: 11)),
                      Text(AudioStoryNowPlaying._fmt(total),
                          style:
                              TextStyle(color: c.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Slide-up açılış (alttan yukarı kayan now-playing ekranı). Global mini'den
/// de çağrılır (Navigator ağacının DIŞINDA yaşar) → root key ile push edilir.
/// Açıkken global mini gizlenir; nasıl kapanırsa kapansın (geri, durdur)
/// `.then` ile geri görünür.
void openAudioStoryNowPlaying(BuildContext context) {
  final nav = rootNavigatorKey.currentState ?? Navigator.of(context);
  fullScreenPlayerOpen.value = true;
  nav
      .push(PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => const AudioStoryNowPlaying(),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ))
      .then((_) => fullScreenPlayerOpen.value = false);
}
