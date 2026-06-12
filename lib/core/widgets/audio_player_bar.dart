import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';

/// A compact, reusable "music-program" transport bar driven by a [just_audio]
/// [AudioPlayer] — slim seek slider + previous / play-pause / next + the current
/// track title and a position/duration readout. Pinned to the bottom of a screen
/// (e.g. `SelayaScaffold.bottomBar`) so playback controls follow the user as they
/// scroll. Shown by the Quran reader and the audio-stories list.
class AudioPlayerBar extends StatelessWidget {
  final AudioPlayer player;
  final String title;
  final String? subtitle;

  /// Show previous/next (playlist) buttons. Off for single-track playback.
  final bool showSkip;
  final VoidCallback? onClose;

  const AudioPlayerBar({
    super.key,
    required this.player,
    required this.title,
    this.subtitle,
    this.showSkip = true,
    this.onClose,
  });

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.gold.withValues(alpha: 0.25))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Transport controls (UP), centred; close button at the right ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 4, 0),
              child: Row(
                children: [
                  const SizedBox(width: 40), // balances the close button
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (showSkip)
                          IconButton(
                            icon: Icon(AppIcons.skipPrev, color: c.textPrimary),
                            onPressed: player.seekToPrevious,
                          ),
                        _playPause(c),
                        if (showSkip)
                          IconButton(
                            icon: Icon(AppIcons.skipNext, color: c.textPrimary),
                            onPressed: player.seekToNext,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: onClose == null
                        ? null
                        : IconButton(
                            visualDensity: VisualDensity.compact,
                            icon:
                                Icon(Icons.close_rounded, color: c.textTertiary),
                            onPressed: onClose,
                          ),
                  ),
                ],
              ),
            ),
            _seek(context, c),
            // ── Surah / track info + elapsed-total readout (DOWN) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w700)),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: c.textTertiary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _times(context, c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playPause(SelayaColors c) => StreamBuilder<PlayerState>(
        stream: player.playerStateStream,
        builder: (context, snap) {
          final s = snap.data;
          final completed = s?.processingState == ProcessingState.completed;
          final playing = (s?.playing ?? false) && !completed;
          final busy = s?.processingState == ProcessingState.loading ||
              s?.processingState == ProcessingState.buffering;
          return Container(
            decoration: BoxDecoration(color: c.gold, shape: BoxShape.circle),
            child: IconButton(
              iconSize: 28,
              icon: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Color(0xFF1A1203)))
                  : Icon(playing ? AppIcons.pause : AppIcons.play,
                      color: const Color(0xFF1A1203)),
              onPressed: () => playing ? player.pause() : player.play(),
            ),
          );
        },
      );

  Widget _seek(BuildContext context, SelayaColors c) => StreamBuilder<Duration?>(
        stream: player.durationStream,
        builder: (context, durSnap) {
          final total = durSnap.data ?? Duration.zero;
          return StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, posSnap) {
              var pos = posSnap.data ?? Duration.zero;
              if (pos > total) pos = total;
              final maxMs = total.inMilliseconds.toDouble();
              final value = maxMs <= 0
                  ? 0.0
                  : pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
                  onChanged: maxMs <= 0
                      ? null
                      : (v) => player.seek(Duration(milliseconds: v.round())),
                ),
              );
            },
          );
        },
      );

  Widget _times(BuildContext context, SelayaColors c) => StreamBuilder<Duration?>(
        stream: player.durationStream,
        builder: (context, durSnap) {
          final total = durSnap.data ?? Duration.zero;
          return StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, posSnap) {
              var pos = posSnap.data ?? Duration.zero;
              if (pos > total) pos = total;
              return Text('${_fmt(pos)} / ${_fmt(total)}',
                  style: AppTypography.tabular(Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(color: c.textTertiary)));
            },
          );
        },
      );
}
