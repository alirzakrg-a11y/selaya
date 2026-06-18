import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'geometric_background.dart';

/// Scaffold with the signature geometric backdrop and an optional transparent
/// app bar. Use across all screens for a consistent premium look.
class SelayaScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final bool showBack;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final bool safeTop;
  final double patternOpacity;
  /// Başlık çubuğu yüksekliği (null = Material varsayılanı 56). Liste ağırlıklı
  /// ekranlarda (Kur'an gibi) daha alçak verilip içeriğe yer açılır.
  final double? toolbarHeight;

  const SelayaScaffold({
    super.key,
    required this.body,
    this.title,
    this.showBack = false,
    this.actions,
    this.leading,
    this.bottomBar,
    this.floatingActionButton,
    this.safeTop = true,
    this.patternOpacity = 0.05,
    this.toolbarHeight,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasAppBar = title != null || showBack || leading != null || actions != null;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.bg,
      floatingActionButton: floatingActionButton,
      // 🎛️ Mini çalarlar artık burada DEĞİL: app.dart'taki
      // GlobalMiniPlayerOverlay tüm rotaların üstünde TEK instance render eder
      // (sekme/sayfa başına kopya yok). Buraya yalnızca sayfanın KENDİ barı
      // gelir (okuyucunun sure kumandası gibi).
      bottomNavigationBar: bottomBar,
      appBar: hasAppBar
          ? AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: toolbarHeight,
              title: title == null ? null : Text(title!),
              leading: leading ??
                  (showBack
                      ? IconButton(
                          icon: Icon(AppIcons.back, color: c.textPrimary),
                          onPressed: () => Navigator.of(context).maybePop(),
                        )
                      : null),
              actions: actions,
            )
          : null,
      body: GeometricBackground(
        patternOpacity: patternOpacity,
        child: safeTop ? SafeArea(child: body) : body,
      ),
    );
  }
}
