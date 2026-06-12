import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/prayer_repository.dart';
import '../../domain/prayer.dart';

/// A 24-hour analog dial of the day's prayer arc: track ring, the current
/// interval, a bright progress arc up to "now", prayer dots and a moving knob.
/// The center shows the next prayer + live countdown.
class PrayerClockDial extends ConsumerWidget {
  const PrayerClockDial({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final v = ref.watch(prayerViewProvider).value;
    if (v == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        // Tighter outer padding (#7) → a noticeably larger dial. The painter
        // scales its ring, ticks and labels to the size so nothing overflows.
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CustomPaint(
          painter: _DialPainter(
            times: [
              for (final e in v.today.ordered)
                (slot: e.key, time: e.value, name: e.key.labelKey.tr())
            ],
            currentSlot: v.currentSlot,
            prevTime: v.prevTime,
            nextTime: v.nextTime,
            now: now,
            track: c.border,
            gold: c.gold,
            goldBright: c.goldBright,
            dotColor: c.textTertiary,
          ),
          child: Center(
            // Constrain the centre block to the dial's inner area and let it
            // scale down if ever too tight (#7: "yazılar taşmasın").
            child: FractionallySizedBox(
              widthFactor: 0.52,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v.nextSlot.labelKey.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: c.gold)),
                    const SizedBox(height: 2),
                    Text(formatCountdown(v.remaining(now)),
                        style:
                            AppTypography.countdown(c.textPrimary, fontSize: 34)),
                    Text('prayer.remaining'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: c.textTertiary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final List<({PrayerSlot slot, DateTime time, String name})> times;
  final PrayerSlot currentSlot;
  final DateTime prevTime;
  final DateTime nextTime;
  final DateTime now;
  final Color track;
  final Color gold;
  final Color goldBright;
  final Color dotColor;

  _DialPainter({
    required this.times,
    required this.currentSlot,
    required this.prevTime,
    required this.nextTime,
    required this.now,
    required this.track,
    required this.gold,
    required this.goldBright,
    required this.dotColor,
  });

  double _frac(DateTime t) =>
      (t.hour * 3600 + t.minute * 60 + t.second) / 86400.0;

  double _angle(double frac) => frac * 2 * math.pi - math.pi / 2;

  Offset _onRing(Offset center, double radius, double frac) {
    final a = _angle(frac);
    return Offset(center.dx + radius * math.cos(a), center.dy + radius * math.sin(a));
  }

  void _arc(Canvas canvas, Rect rect, double from, double to, Paint p) {
    final start = _angle(from);
    var sweep = (to - from) * 2 * math.pi;
    if (sweep < 0) sweep += 2 * math.pi;
    canvas.drawArc(rect, start, sweep, false, p);
  }

  /// Prayer name placed just OUTSIDE the ring, anchored so the text always
  /// extends away from the centre (never crossing the ring) and clamped to the
  /// paint bounds so nothing clips on a compact dial. Right-side names slide
  /// right, left-side names left, top/bottom names stay centred.
  void _ringLabel(Canvas canvas, String s, Offset center, Size size,
      double labelRadius, double frac,
      {required Color color, required double fontSize, required FontWeight weight}) {
    final a = _angle(frac);
    final cosA = math.cos(a), sinA = math.sin(a);
    final ax = center.dx + cosA * labelRadius;
    final ay = center.dy + sinA * labelRadius;
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = ax - tp.width / 2 + cosA * tp.width / 2;
    var dy = ay - tp.height / 2 + sinA * tp.height / 2;
    dx = dx.clamp(0.0, (size.width - tp.width).clamp(0.0, double.infinity));
    dy = dy.clamp(0.0, (size.height - tp.height).clamp(0.0, double.infinity));
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Scale every fixed dimension to the dial size (reference 300px) so the
    // ring, ticks, dots and labels stay proportional and never overflow on
    // small/large screens (#7: responsive, "yazılar taşmasın").
    final u = size.shortestSide / 300;
    final radius = size.shortestSide / 2 - 42 * u;
    final rect = Rect.fromCircle(center: center, radius: radius);

    Paint stroke(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * u
      ..strokeCap = StrokeCap.round
      ..color = color;

    // Hour ticks (24) — subtle clock-face reference.
    for (var h = 0; h < 24; h++) {
      final a = _angle(h / 24.0);
      final isMajor = h % 6 == 0;
      final outer = radius + 5 * u;
      final inner = radius + (isMajor ? -1 : 2) * u;
      canvas.drawLine(
        Offset(center.dx + math.cos(a) * inner, center.dy + math.sin(a) * inner),
        Offset(center.dx + math.cos(a) * outer, center.dy + math.sin(a) * outer),
        Paint()
          ..color = dotColor.withValues(alpha: isMajor ? 0.8 : 0.28)
          ..strokeWidth = (isMajor ? 2 : 1) * u,
      );
    }

    // Track ring
    canvas.drawCircle(center, radius, stroke(track));

    // Current interval (subtle)
    _arc(canvas, rect, _frac(prevTime), _frac(nextTime),
        stroke(gold.withValues(alpha: 0.22)));

    // Progress within the interval (bright)
    _arc(canvas, rect, _frac(prevTime), _frac(now), stroke(goldBright));

    // Prayer dots (on the ring) + names placed just outside, around the dial.
    for (final e in times) {
      final frac = _frac(e.time);
      final isCurrent = e.slot == currentSlot;
      canvas.drawCircle(
        _onRing(center, radius, frac),
        (isCurrent ? 5 : 3) * u,
        Paint()..color = isCurrent ? goldBright : dotColor,
      );
      _ringLabel(canvas, e.name, center, size, radius + 14 * u, frac,
          color: isCurrent ? goldBright : dotColor.withValues(alpha: 0.95),
          fontSize: (10 * u).clamp(9, 13),
          weight: isCurrent ? FontWeight.w700 : FontWeight.w500);
    }

    // "Now" knob
    final knob = _onRing(center, radius, _frac(now));
    canvas.drawCircle(knob, 6.5 * u, Paint()..color = goldBright);
    canvas.drawCircle(
        knob,
        6.5 * u,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * u
          ..color = track);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.now != now ||
      old.nextTime != nextTime ||
      old.currentSlot != currentSlot;
}
