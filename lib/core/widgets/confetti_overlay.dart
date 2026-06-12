import 'dart:math';

import 'package:flutter/material.dart';

/// Tam ekran havai fişek / konfeti patlaması — günlük görevler tamamlanınca.
/// Overlay'e eklenir, ~2 sn oynar, kendini kaldırır. HARİCİ PAKET gerektirmez
/// (AnimationController + CustomPainter; saf Flutter).
void celebrate(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ConfettiLayer(onDone: () {
      entry.remove();
    }),
  );
  overlay.insert(entry);
}

class _ConfettiLayer extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiLayer({required this.onDone});

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _parts;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    const colors = [
      Color(0xFFE7B85C),
      Color(0xFFD9A441),
      Color(0xFFE0556B),
      Color(0xFF46D08A),
      Color(0xFF5AA9E6),
      Color(0xFFF2F2F2),
    ];
    // 3 patlama merkezi (sol / orta / sağ üst) → havai fişek hissi.
    const centers = [0.25, 0.5, 0.75];
    _parts = List.generate(120, (i) {
      final ang = _rng.nextDouble() * 2 * pi;
      final spd = 0.22 + _rng.nextDouble() * 0.62;
      return _Particle(
        cx: centers[i % 3],
        cy: 0.30 + _rng.nextDouble() * 0.06,
        vx: cos(ang) * spd,
        vy: sin(ang) * spd - 0.18,
        color: colors[_rng.nextInt(colors.length)],
        size: 5 + _rng.nextDouble() * 7,
        rot: _rng.nextDouble() * 2 * pi,
        rotSpd: (_rng.nextDouble() - 0.5) * 0.6,
      );
    });
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1900))
      ..addListener(() => setState(() {}))
      ..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_parts, _c.value),
      ),
    );
  }
}

class _Particle {
  final double cx, cy, vx, vy, size, rot, rotSpd;
  final Color color;
  const _Particle({
    required this.cx,
    required this.cy,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rot,
    required this.rotSpd,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> parts;
  final double t; // 0..1
  const _ConfettiPainter(this.parts, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 1.4;
    final fade = (1 - t * t).clamp(0.0, 1.0); // sona doğru hızlı kaybol
    final p = Paint();
    for (final part in parts) {
      final x = (part.cx + part.vx * t) * size.width;
      final y =
          (part.cy + part.vy * t + 0.5 * gravity * t * t) * size.height;
      p.color = part.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(part.rot + part.rotSpd * t * 24);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: part.size, height: part.size * 0.55),
          const Radius.circular(2),
        ),
        p,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
