import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import 'audio_stories_screen.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final int initialIndex;
  const AudioPlayerScreen({
    super.key,
    required this.categoryId,
    required this.initialIndex,
  });

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  AudioStoryCategory? _category;
  bool _loaded = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final cats = await ref.read(audioStoriesProvider.future);
      final matches = cats.where((c) => c.id == widget.categoryId);
      if (matches.isEmpty) {
        if (mounted) setState(() => _error = true);
        return;
      }
      final cat = matches.first;
      addRecentAudio(ref.read(sharedPreferencesProvider), widget.categoryId,
          widget.initialIndex);
      final audio = ref.read(audioPlayerProvider);
      final sources = [
        for (final e in cat.episodes) AudioSource.uri(Uri.parse(e.audio))
      ];
      await audio.setPlaylist(sources,
          initialIndex: widget.initialIndex.clamp(0, sources.length - 1));
      if (mounted) {
        setState(() {
          _category = cat;
          _loaded = true;
        });
      }
      // NOT awaited: just_audio'da play()'in future'ı ancak çalma duraklayınca/
      // bitince tamamlanır; await edilirse yükleyici sonsuza dek bloke olur ve
      // ekran "yükleniyor"da donar (bildirilen donmanın sebebi buydu).
      audio.play();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    // No background playback yet → stop when leaving the player.
    ref.read(audioPlayerProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final audio = ref.read(audioPlayerProvider);
    final cat = _category;

    return SelayaScaffold(
      title: cat?.title(lang) ?? 'audioStories.title'.tr(),
      showBack: true,
      body: _error
          ? const SelayaError(error: 'audio')
          : cat == null || !_loaded
              ? const SelayaLoading()
              : StreamBuilder<int?>(
                  stream: audio.currentIndexStream,
                  builder: (context, snap) {
                    final idx =
                        (snap.data ?? audio.currentIndex ?? 0).clamp(0, cat.episodes.length - 1);
                    final ep = cat.episodes[idx];
                    return _PlayerBody(category: cat, episode: ep, lang: lang);
                  },
                ),
    );
  }
}

class _PlayerBody extends ConsumerWidget {
  final AudioStoryCategory category;
  final AudioEpisode episode;
  final String lang;
  const _PlayerBody({
    required this.category,
    required this.episode,
    required this.lang,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final audio = ref.read(audioPlayerProvider);
    final cover = episode.cover.isNotEmpty ? episode.cover : category.cover;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.base, AppSpacing.lg, AppSpacing.xxxl),
      children: [
        ClipRRect(
          borderRadius: AppRadius.rXxl,
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage.cdn(cover, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x0005070D), Color(0x9905070D)],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Icon(audioIconFor(category.iconKey),
                      color: category.accentColor, size: 30),
                ),
              ],
            ),
          ),
        ),
        const Gap.lg(),
        Text(episode.title(lang),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const Gap.xs(),
        Text(episode.subtitle(lang),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: c.textTertiary)),
        const Gap.lg(),
        _SeekBar(audio: audio),
        const Gap.md(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 36,
              icon: Icon(AppIcons.skipPrev, color: c.textPrimary),
              onPressed: audio.previous,
            ),
            const Gap.lg(),
            StreamBuilder<PlayerState>(
              stream: audio.playerStateStream,
              builder: (context, snap) {
                final playing = snap.data?.playing ?? false;
                final completed =
                    snap.data?.processingState == ProcessingState.completed;
                return Container(
                  decoration:
                      BoxDecoration(color: c.gold, shape: BoxShape.circle),
                  child: IconButton(
                    iconSize: 40,
                    icon: Icon(
                        playing && !completed ? AppIcons.pause : AppIcons.play,
                        color: const Color(0xFF1A1203)),
                    onPressed: audio.togglePlay,
                  ),
                );
              },
            ),
            const Gap.lg(),
            IconButton(
              iconSize: 36,
              icon: Icon(AppIcons.skipNext, color: c.textPrimary),
              onPressed: audio.next,
            ),
          ],
        ),
      ],
    );
  }
}

class _SeekBar extends StatelessWidget {
  final AudioService audio;
  const _SeekBar({required this.audio});

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StreamBuilder<Duration?>(
      stream: audio.durationStream,
      builder: (context, durSnap) {
        final total = durSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: audio.positionStream,
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
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: c.gold,
                    inactiveTrackColor: c.border,
                    thumbColor: c.gold,
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs <= 0 ? 1 : maxMs,
                    value: value,
                    onChanged: (v) =>
                        audio.seek(Duration(milliseconds: v.round())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(pos),
                          style: AppTypography.tabular(Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: c.textTertiary))),
                      Text(_fmt(total),
                          style: AppTypography.tabular(Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: c.textTertiary))),
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
