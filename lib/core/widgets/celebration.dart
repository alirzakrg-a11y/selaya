import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Tam ekran havai fişek / konfeti patlaması + tebrik kartı. Bir başarı
/// kazanılınca (ör. günün 5 vaktini tamamlayınca) [showCelebration] ile çağrılır.
/// Hiçbir dış paket gerektirmez — parçacıklar CustomPainter ile çizilir.
Future<void> showCelebration(BuildContext context,
    {required String title, required String message}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    barrierDismissible: true,
    builder: (_) => _CelebrationDialog(title: title, message: message),
  );
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  const _Particle(this.angle, this.speed, this.size, this.color);
}

class _CelebrationDialog extends StatefulWidget {
  final String title;
  final String message;
  const _CelebrationDialog({required this.title, required this.message});
  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    const colors = [
      AppColors.gold,
      AppColors.goldBright,
      Color(0xFF4FC3F7),
      Color(0xFF81C784),
      Color(0xFFE57373),
      Color(0xFFBA68C8),
    ];
    _particles = List.generate(60, (i) {
      return _Particle(
        rnd.nextDouble() * math.pi * 2,
        130 + rnd.nextDouble() * 260,
        4 + rnd.nextDouble() * 7,
        colors[rnd.nextInt(colors.length)],
      );
    });
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..forward();
    Future.delayed(const Duration(milliseconds: 2700), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ac,
              builder: (_, _) => CustomPaint(
                painter: _ConfettiPainter(_particles, _ac.value),
              ),
            ),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.xl),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: AppRadius.rXl,
                border: Border.all(color: c.gold.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                      color: c.gold.withValues(alpha: 0.18),
                      blurRadius: 30,
                      spreadRadius: 4),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 52)),
                  const Gap.md(),
                  Text(widget.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: c.gold, fontWeight: FontWeight.w800)),
                  const Gap.sm(),
                  Text(widget.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: c.textSecondary, height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0..1
  const _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.40);
    final paint = Paint();
    for (final p in particles) {
      final dx = math.cos(p.angle) * p.speed * t;
      final dy = math.sin(p.angle) * p.speed * t + 0.5 * 460 * t * t;
      final pos = origin + Offset(dx, dy);
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.angle + t * 6);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
