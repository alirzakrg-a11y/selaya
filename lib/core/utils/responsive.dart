import 'package:flutter/widgets.dart';

/// Lightweight responsive helpers so layouts adapt across small phones (e.g.
/// iPhone SE), regular phones, and large/tablet screens without per-screen math.
extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  /// Narrow phones (SE / small Androids).
  bool get isCompact => screenWidth < 360;

  /// Tablets / large foldables / desktop.
  bool get isExpanded => screenWidth >= 600;

  /// Column count for icon grids that grows with available width.
  int gridColumns({int min = 3, int max = 5}) {
    final w = screenWidth;
    if (w >= 1000) return max;
    if (w >= 700) return (max - 1).clamp(min, max);
    if (w >= 600) return (min + 1).clamp(min, max);
    return min;
  }

  /// Scales a base spacing value down a touch on compact screens.
  double scaledGap(double base) => isCompact ? base * 0.85 : base;
}
