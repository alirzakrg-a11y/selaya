import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// The read-aloud sibling of [AudioPlayerBar]: same music-program look, but
/// driven by a simple [speaking] flag + callbacks instead of a [just_audio]
/// player (TTS has no seekable position/duration). Used by Dualar / Esmaül Hüsna.
class TtsReaderBar extends StatelessWidget {
  final bool speaking;
  final String title;
  final String? subtitle;
  final VoidCallback onPlayPause;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onClose;

  const TtsReaderBar({
    super.key,
    required this.speaking,
    required this.title,
    this.subtitle,
    required this.onPlayPause,
    this.onPrev,
    this.onNext,
    required this.onClose,
  });

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(AppIcons.skipPrev,
                    color: onPrev == null ? c.textTertiary : c.textPrimary),
                onPressed: onPrev,
              ),
              Container(
                decoration: BoxDecoration(color: c.gold, shape: BoxShape.circle),
                child: IconButton(
                  iconSize: 28,
                  icon: Icon(speaking ? AppIcons.pause : AppIcons.play,
                      color: const Color(0xFF1A1203)),
                  onPressed: onPlayPause,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(AppIcons.skipNext,
                    color: onNext == null ? c.textTertiary : c.textPrimary),
                onPressed: onNext,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: c.textPrimary, fontWeight: FontWeight.w700)),
                    Row(
                      children: [
                        Icon(
                            speaking
                                ? Icons.graphic_eq_rounded
                                : Icons.volume_up_rounded,
                            size: 13,
                            color: c.gold),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(subtitle ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: c.textTertiary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, color: c.textTertiary),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
