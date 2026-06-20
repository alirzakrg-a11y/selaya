import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/prayer_repository.dart';
import '../../domain/prayer.dart';

/// A horizontal 24-hour timeline of the day's prayer & extended times, with a
/// live "now" marker — the swipe-to alternate gauge requested in the PDF.
class PrayerTimelineGauge extends ConsumerWidget {
  const PrayerTimelineGauge({super.key});

  static const double _timelineHeight = 112;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final v = ref.watch(prayerViewProvider).value;
    final ext = ref.watch(extendedTimesProvider).value;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    if (v == null) return const SizedBox.shrink();

    // Day spans imsak → imsak + 24h; everything wraps into [0,1].
    final start = v.today.imsak;
    double frac(DateTime t) {
      var f = t.difference(start).inSeconds / 86400.0;
      while (f < 0) {
        f += 1;
      }
      while (f > 1) {
        f -= 1;
      }
      return f;
    }

    final prayers = [
      for (final s in PrayerSlot.values)
        (f: frac(v.today.timeOf(s)), name: s.labelKey.tr(),
            time: formatClock(v.today.timeOf(s)))
    ];

    final extended = <({double f, String name})>[];
    if (ext != null) {
      for (final key in ['prayer.israk', 'prayer.evvabin', 'prayer.seher']) {
        final seg = ext.segments.where((e) => e.labelKey == key);
        if (seg.isNotEmpty && seg.first.isValid) {
          extended.add((f: frac(seg.first.start), name: key.tr()));
        }
      }
    }
    final kerahat = <({double a, double b})>[
      if (ext != null)
        for (final k in ext.kerahat)
          if (k.isValid) (a: frac(k.start), b: frac(k.end!)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(v.nextSlot.labelKey.tr(),
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: c.gold)),
          const SizedBox(height: 2),
          Text(formatCountdown(v.remaining(now)),
              style: AppTypography.countdown(c.textPrimary, fontSize: 34)),
          Text('prayer.remaining'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textTertiary)),
          const Gap.base(),
          SizedBox(
            height: _timelineHeight,
            child: CustomPaint(
              size: const Size(double.infinity, _timelineHeight),
              painter: _TimelinePainter(
                prayers: prayers,
                extended: extended,
                kerahat: kerahat,
                nowFrac: frac(now),
                track: c.surfaceAlt,
                gold: c.gold,
                goldBright: c.goldBright,
                red: c.danger,
                text: c.textPrimary,
                dim: c.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final List<({double f, String name, String time})> prayers;
  final List<({double f, String name})> extended;
  final List<({double a, double b})> kerahat;
  final double nowFrac;
  final Color track, gold, goldBright, red, text, dim;
  _TimelinePainter({
    required this.prayers,
    required this.extended,
    required this.kerahat,
    required this.nowFrac,
    required this.track,
    required this.gold,
    required this.goldBright,
    required this.red,
    required this.text,
    required this.dim,
  });

  void _label(Canvas canvas, String s, double cx, double y,
      {required double maxW, required Color color, double size = 9, FontWeight w = FontWeight.w500}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s, style: TextStyle(color: color, fontSize: size, fontWeight: w)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout();
    var dx = cx - tp.width / 2;
    dx = dx.clamp(0.0, maxW - tp.width);
    tp.paint(canvas, Offset(dx, y));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 10.0;
    final left = pad, right = size.width - pad;
    final barW = right - left;
    final barY = size.height * 0.46;
    const barH = 12.0;
    double x(double f) => left + f * barW;

    final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, barY - barH / 2, barW, barH),
        const Radius.circular(barH / 2));

    // track
    canvas.drawRRect(barRect, Paint()..color = track);

    // elapsed fill up to "now"
    canvas.save();
    canvas.clipRRect(barRect);
    canvas.drawRect(Rect.fromLTWH(left, barY - barH / 2, nowFrac * barW, barH),
        Paint()..color = gold.withValues(alpha: 0.30));
    // kerahat (forbidden) windows
    for (final k in kerahat) {
      final a = x(k.a), b = x(k.b);
      if (b > a) {
        canvas.drawRect(Rect.fromLTWH(a, barY - barH / 2, b - a, barH),
            Paint()..color = red.withValues(alpha: 0.55));
      }
    }
    canvas.restore();

    // extended-time ticks + labels (above the bar)
    for (final e in extended) {
      final ex = x(e.f);
      canvas.drawLine(Offset(ex, barY - barH / 2 - 4),
          Offset(ex, barY - barH / 2), Paint()
            ..color = goldBright
            ..strokeWidth = 1.5);
      _label(canvas, e.name, ex, barY - barH / 2 - 18,
          maxW: size.width, color: goldBright, size: 8.5, w: FontWeight.w600);
    }

    // prayer ticks + labels (below the bar, staggered into two rows so close
    // times like İmsak/Güneş don't overlap)
    for (var i = 0; i < prayers.length; i++) {
      final p = prayers[i];
      final px = x(p.f);
      final row = i.isEven ? 0.0 : 26.0;
      canvas.drawLine(
          Offset(px, barY - barH / 2),
          Offset(px, barY + barH / 2 + 2 + row),
          Paint()
            ..color = gold.withValues(alpha: row == 0 ? 1 : 0.4)
            ..strokeWidth = 1.5);
      _label(canvas, p.name, px, barY + barH / 2 + 6 + row,
          maxW: size.width, color: dim, size: 8.5);
      _label(canvas, p.time, px, barY + barH / 2 + 18 + row,
          maxW: size.width, color: text, size: 10.5, w: FontWeight.w700);
    }

    // "now" marker
    final nx = x(nowFrac);
    canvas.drawLine(
        Offset(nx, barY - barH / 2 - 5),
        Offset(nx, barY + barH / 2 + 5),
        Paint()
          ..color = goldBright
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(nx, barY), 5, Paint()..color = goldBright);
    canvas.drawCircle(
        Offset(nx, barY),
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = track);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.nowFrac != nowFrac || old.prayers != prayers;
}
