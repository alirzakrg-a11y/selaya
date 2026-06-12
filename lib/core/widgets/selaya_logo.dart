import 'package:flutter/material.dart';

/// SELAYA brand mark — a gold crescent cradling an 8-pointed star, optionally
/// with the "SELAYA" wordmark beneath. Rendered from the vector logo files
/// (designed in Illustrator/Corel) so it stays crisp at any size.
class SelayaLogo extends StatelessWidget {
  /// Logo width. For the mark-only variant this is also the height (the mark
  /// is square); with the wordmark the height grows with the artwork's ratio.
  final double size;
  final bool showWordmark;
  const SelayaLogo({super.key, this.size = 96, this.showWordmark = true});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      showWordmark
          ? 'assets/branding/selaya_logo_full.png'
          : 'assets/branding/selaya_mark.png',
      width: size,
      fit: BoxFit.contain,
    );
  }
}
