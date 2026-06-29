import 'package:flutter/material.dart';

/// Çift-tıkla beğen geri bildirimi — ekran ortasında büyüyüp sönen kalp.
/// [show] ile overlay'e bir kez eklenir; animasyon bitince kendini kaldırır.
class DoubleTapHeartAnimation extends StatefulWidget {
  final VoidCallback onDone;
  const DoubleTapHeartAnimation({super.key, required this.onDone});

  /// Ekrana bir kez kalp animasyonu bas. Overlay yoksa sessizce no-op.
  static void show(BuildContext context) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => DoubleTapHeartAnimation(onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  @override
  State<DoubleTapHeartAnimation> createState() =>
      _DoubleTapHeartAnimationState();
}

class _DoubleTapHeartAnimationState extends State<DoubleTapHeartAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = _c.value;
            // İlk %40: easeOutBack ile 1.15'e büyü; sonrası hafif küçül.
            final scale = t < 0.4
                ? Curves.easeOutBack.transform(t / 0.4) * 1.15
                : 1.15 - (t - 0.4) / 0.6 * 0.15;
            // Son %35'te sön.
            final opacity = t < 0.65 ? 1.0 : (1 - (t - 0.65) / 0.35);
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale.clamp(0.0, 1.3),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFE5556B),
                  size: 96,
                  shadows: [Shadow(color: Color(0x66000000), blurRadius: 18)],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
