import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../data/audio_handler.dart';
import '../data/audio_story_controller.dart';
import 'audio_stories_screen.dart';

/// Tam-ekran oynatıcı: ÖNCE açılır (donma yok), sonra arka planda indirir+çalar
/// (storyCaching "indiriliyor"). Küçültülmüş kapak + ilerleme + kontroller +
/// hız/zamanlayıcı/favori/TEKRAR + hikâye metni (oku) + alttaki bölüm listesi.
/// Arka planda çalar (bildirimden kontrol); ekrandan çıkınca DURMAZ.
class AudioPlayerScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final int initialIndex;
  const AudioPlayerScreen(
      {super.key, required this.categoryId, required this.initialIndex});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  AudioStoryCategory? _category;
  bool _loaded = false;
  bool _error = false;
  Timer? _sleepTimer;
  int? _sleepMinutes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final lang = context.langCode;
      final cats = await ref.read(audioStoriesProvider.future);
      final matches = cats.where((c) => c.id == widget.categoryId);
      if (matches.isEmpty) {
        if (mounted) setState(() => _error = true);
        return;
      }
      final cat = matches.first;
      final start = widget.initialIndex.clamp(0, cat.episodes.length - 1);
      addRecentAudio(
          ref.read(sharedPreferencesProvider), widget.categoryId, start);
      // ① ÖNCE ekranı aç (donma hissi gitsin), SONRA arka planda indir+çal.
      if (mounted) {
        setState(() {
          _category = cat;
          _loaded = true;
        });
      }
      final h = ref.read(audioHandlerProvider);
      final same = h.mode == 'story' &&
          h.tracks.isNotEmpty &&
          h.tracks.length == cat.episodes.length &&
          h.tracks.first.id == '${cat.id}_0';
      if (!same) {
        unawaited(ref
            .read(audioStoryControllerProvider.notifier)
            .play(cat, start, lang));
      } else if ((h.player.currentIndex ?? -1) != start) {
        unawaited(
            ref.read(audioStoryControllerProvider.notifier).jumpTo(start));
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose(); // arka plan çalmaya devam — bildirimden kontrol.
  }

  void _setSleep(int? minutes) {
    _sleepTimer?.cancel();
    setState(() => _sleepMinutes = minutes);
    if (minutes != null) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        // Widget dispose edildiyse (ekran kapandı + timer yarıştı) ref.read
        // disposed context'te çağrılmasın → ÖNCE mounted guard (E1: race fix).
        if (!mounted) return;
        ref.read(audioStoryControllerProvider.notifier).stop();
        setState(() => _sleepMinutes = null);
        Navigator.of(context).maybePop();
      });
    }
  }

  void _pickSleep() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Widget opt(String label, int? min) => ListTile(
              title: Text(label),
              trailing: _sleepMinutes == min
                  ? Icon(Icons.check_rounded, color: c.gold)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _setSleep(min);
              },
            );
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Gap.md(),
            Text('audioStories.sleepTitle'.tr(),
                style: Theme.of(ctx).textTheme.titleMedium),
            const Gap.sm(),
            opt('audioStories.sleepOff'.tr(), null),
            opt('audioStories.sleepMinutes'.tr(args: const ['15']), 15),
            opt('audioStories.sleepMinutes'.tr(args: const ['30']), 30),
            opt('audioStories.sleepMinutes'.tr(args: const ['60']), 60),
            const Gap.sm(),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final cat = _category;
    if (_error) {
      return const SelayaScaffold(
          showBack: true, body: SelayaError(error: 'audio'));
    }
    if (cat == null || !_loaded) {
      return const SelayaScaffold(showBack: true, body: SelayaLoading());
    }
    final ctrl = ref.read(audioStoryControllerProvider.notifier);
    final st = ref.watch(audioStoryControllerProvider);
    return SelayaScaffold(
      showBack: true,
      body: StreamBuilder<int?>(
        stream: ctrl.currentIndexStream,
        builder: (context, snap) {
          final idx = (snap.data ?? ctrl.currentIndex)
              .clamp(0, cat.episodes.length - 1);
          return _body(
              context, cat, cat.episodes[idx], idx, lang, st.playing, st.loading);
        },
      ),
    );
  }

  Widget _body(BuildContext context, AudioStoryCategory cat, AudioEpisode ep,
      int idx, String lang, bool playing, bool loading) {
    final c = context.colors;
    final ctrl = ref.read(audioStoryControllerProvider.notifier);
    final prefs = ref.read(sharedPreferencesProvider);
    final cover = ep.cover.isNotEmpty ? ep.cover : cat.cover;
    final fav = isFavoriteAudio(prefs, cat.id, idx);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl),
      children: [
        // ⑥ Küçültülmüş kapak (ortalı, ekran genişliğinin %58'i)
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.58),
            child: ClipRRect(
              borderRadius: AppRadius.rXxl,
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(fit: StackFit.expand, children: [
                  AppImage.cdn(cover, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x0005070D), Color(0x5505070D)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(100)),
                      child: Text('${idx + 1} / ${cat.episodes.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const Gap.md(),
        Text(ep.title(lang),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const Gap.sm(),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
                color: cat.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(100)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(audioIconFor(cat.iconKey), color: cat.accentColor, size: 16),
              const Gap.xs(),
              Text(cat.title(lang),
                  style: TextStyle(
                      color: cat.accentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ]),
          ),
        ),
        const Gap.md(),
        _SeekBar(ctrl: ctrl),
        // ② İndiriliyor göstergesi
        ValueListenableBuilder<bool>(
          valueListenable: storyCaching,
          builder: (_, downloading, _) => downloading
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.gold)),
                      const Gap.xs(),
                      Text('audioStories.downloading'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: c.textTertiary)),
                    ],
                  ),
                )
              : const SizedBox(height: 4),
        ),
        const Gap.sm(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              iconSize: 28,
              icon: Icon(Icons.replay_10_rounded, color: c.textSecondary),
              onPressed: () => ctrl.seek(_back(ctrl.position)),
            ),
            IconButton(
              iconSize: 32,
              icon: Icon(AppIcons.skipPrev, color: c.textPrimary),
              onPressed: ctrl.previous,
            ),
            // Oynat/duraklat — indirme/buffer sırasında spinner.
            ValueListenableBuilder<bool>(
              valueListenable: storyCaching,
              builder: (_, downloading, _) {
                final busy = downloading || loading;
                return Container(
                  width: 66,
                  height: 66,
                  decoration:
                      BoxDecoration(color: c.gold, shape: BoxShape.circle),
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.6, color: Color(0xFF1A1203)))
                      : IconButton(
                          iconSize: 40,
                          icon: Icon(playing ? AppIcons.pause : AppIcons.play,
                              color: const Color(0xFF1A1203)),
                          onPressed: ctrl.toggle),
                );
              },
            ),
            IconButton(
              iconSize: 32,
              icon: Icon(AppIcons.skipNext, color: c.textPrimary),
              onPressed: ctrl.next,
            ),
            IconButton(
              iconSize: 28,
              icon: Icon(Icons.forward_10_rounded, color: c.textSecondary),
              onPressed: () =>
                  ctrl.seek(_fwd(ctrl.position, ctrl.totalDuration)),
            ),
          ],
        ),
        const Gap.lg(),
        Divider(height: 1, color: c.border),
        const Gap.md(),
        // ⑦ Alt sıra: hız / zamanlayıcı / favori / TEKRAR (paylaş kaldırıldı)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomAction(
              icon: Icons.speed_rounded,
              label: '${ctrl.speed}x ${'audioStories.speed'.tr()}',
              onTap: () {
                ctrl.setSpeed(_nextSpeed(ctrl.speed));
                setState(() {});
              },
            ),
            _BottomAction(
              icon: Icons.bedtime_outlined,
              active: _sleepMinutes != null,
              label: _sleepMinutes == null
                  ? 'audioStories.timer'.tr()
                  : 'audioStories.sleepMinutes'.tr(args: ['$_sleepMinutes']),
              onTap: _pickSleep,
            ),
            _BottomAction(
              icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              active: fav,
              label: fav
                  ? 'audioStories.favorited'.tr()
                  : 'audioStories.favorite'.tr(),
              onTap: () {
                toggleFavoriteAudio(prefs, cat.id, idx);
                setState(() {});
              },
            ),
            _BottomAction(
              icon: ctrl.loopOne
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              active: ctrl.loopOne,
              label: 'audioStories.repeat'.tr(),
              onTap: () {
                ctrl.setLoop(!ctrl.loopOne);
                setState(() {});
              },
            ),
          ],
        ),
        // ④ Hikâye metni (oku)
        if (ep.text.trim().isNotEmpty) ...[
          const Gap.lg(),
          _StoryText(text: ep.text),
        ],
        // ⑤ Bölüm listesi (playlist)
        const Gap.lg(),
        Text('audioStories.playlist'.tr(),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const Gap.sm(),
        for (var i = 0; i < cat.episodes.length; i++)
          _PlaylistRow(
            episode: cat.episodes[i],
            number: i + 1,
            lang: lang,
            accent: cat.accentColor,
            active: i == idx,
            onTap: () => ctrl.jumpTo(i),
          ),
      ],
    );
  }

  Duration _back(Duration p) {
    final v = p - const Duration(seconds: 10);
    return v < Duration.zero ? Duration.zero : v;
  }

  Duration _fwd(Duration p, Duration? total) {
    final v = p + const Duration(seconds: 10);
    return (total != null && v > total) ? total : v;
  }

  double _nextSpeed(double s) {
    const speeds = [1.0, 1.25, 1.5, 2.0, 0.75];
    final i = speeds.indexWhere((x) => (x - s).abs() < 0.01);
    return speeds[(i + 1) % speeds.length];
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _BottomAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.active = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.gold : c.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rLg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const Gap.xs(),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _StoryText extends StatefulWidget {
  final String text;
  const _StoryText({required this.text});
  @override
  State<_StoryText> createState() => _StoryTextState();
}

class _StoryTextState extends State<_StoryText> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration:
          BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadius.rLg),
      child: Column(children: [
        InkWell(
          borderRadius: AppRadius.rLg,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(children: [
              Icon(Icons.menu_book_rounded, color: c.gold, size: 20),
              const Gap.md(),
              Expanded(
                  child: Text('audioStories.readText'.tr(),
                      style: Theme.of(context).textTheme.titleSmall)),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: c.textTertiary),
            ]),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, 0, AppSpacing.base, AppSpacing.base),
            child: SelectableText(widget.text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.6, color: c.textSecondary)),
          ),
      ]),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  final AudioEpisode episode;
  final int number;
  final String lang;
  final Color accent;
  final bool active;
  final VoidCallback onTap;
  const _PlaylistRow(
      {required this.episode,
      required this.number,
      required this.lang,
      required this.accent,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rLg,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: active
                ? Icon(Icons.graphic_eq_rounded, color: accent, size: 18)
                : Text('$number',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textTertiary)),
          ),
          const Gap.md(),
          Expanded(
            child: Text(episode.title(lang),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: active
                    ? Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: accent, fontWeight: FontWeight.w700)
                    : Theme.of(context).textTheme.titleSmall),
          ),
          if (episode.durationSec > 0)
            Text(formatDuration(episode.durationSec),
                style: AppTypography.tabular(Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(color: c.textTertiary))),
        ]),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  final AudioStoryController ctrl;
  const _SeekBar({required this.ctrl});

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

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
            return Column(children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
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
                  onChanged: (v) => ctrl.seek(Duration(milliseconds: v.round())),
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
            ]);
          },
        );
      },
    );
  }
}
