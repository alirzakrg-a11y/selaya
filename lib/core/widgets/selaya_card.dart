import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'geometric_background.dart';

/// Standard SELAYA surface card: rounded, subtle border, optional tap. Tappable
/// cards get a gentle press-scale (premium tactile feedback) on top of the ink
/// ripple, applied uniformly everywhere the card is used.
class SelayaCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? color;
  final Gradient? gradient;
  final bool bordered;
  final bool patterned;

  const SelayaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.base),
    this.onTap,
    this.borderRadius = AppRadius.rXl,
    this.color,
    this.gradient,
    this.bordered = true,
    this.patterned = false,
  });

  @override
  State<SelayaCard> createState() => _SelayaCardState();
}

class _SelayaCardState extends State<SelayaCard> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget body = Padding(padding: widget.padding, child: widget.child);
    if (widget.patterned) {
      // Arkaplansız kartlara ince İslami yıldız deseni (kartın tamamını kaplar,
      // köşelere kırpılır) — sade kartlar canlı görünsün.
      body = ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: StarPatternPainter(
                    color:
                        c.gold.withValues(alpha: c.isDark ? 0.05 : 0.06)),
              ),
            ),
            body,
          ],
        ),
      );
    }
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.gradient == null ? (widget.color ?? c.surfaceAlt) : null,
        gradient: widget.gradient,
        borderRadius: widget.borderRadius,
        border:
            widget.bordered ? Border.all(color: c.border, width: 1) : null,
      ),
      child: body,
    );

    if (widget.onTap == null) return content;

    // Listener tracks the pointer for the scale without consuming the tap, so
    // the InkWell still fires onTap and shows its ripple.
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: widget.borderRadius,
            child: content,
          ),
        ),
      ),
    );
  }
}
