import 'package:flutter/material.dart';

/// ANINDA tepki veren dikey kaydırma algılayıcı.
///
/// [Listener] tabanlıdır: jest arenasına HİÇ katılmaz → içindeki oynat/duraklat
/// gibi düğmelerin dokunuşlarını ASLA iptal etmez (GestureDetector'lı eski
/// sürüm, parmak basarken ufak kaymalarda tap'i yutup "düğme çalışmıyor"
/// hissine yol açabiliyordu). Sürükleme [threshold] pikseli geçer geçmez
/// (parmak kalkmadan) tetikler; işaretçi başına bir kez ateşler.
class InstantSwipe extends StatefulWidget {
  final Widget child;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final double threshold;
  const InstantSwipe({
    super.key,
    required this.child,
    this.onUp,
    this.onDown,
    this.threshold = 18,
  });

  @override
  State<InstantSwipe> createState() => _InstantSwipeState();
}

class _InstantSwipeState extends State<InstantSwipe> {
  double _dy = 0;
  double _dx = 0;
  bool _fired = false;
  int? _pointer;

  void _fire(VoidCallback? cb) {
    if (_fired || cb == null) return;
    _fired = true;
    cb();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          _pointer = e.pointer;
          _dy = 0;
          _dx = 0;
          _fired = false;
        },
        onPointerMove: (e) {
          if (e.pointer != _pointer || _fired) return;
          _dy += e.delta.dy;
          _dx += e.delta.dx;
          // Belirgin biçimde YATAY bir hareketse karışma (ör. ilerleme çubuğu).
          if (_dx.abs() > _dy.abs() + 24) return;
          if (_dy <= -widget.threshold) _fire(widget.onUp);
          if (_dy >= widget.threshold) _fire(widget.onDown);
        },
        onPointerUp: (_) => _pointer = null,
        onPointerCancel: (_) => _pointer = null,
        child: widget.child,
      );
}
