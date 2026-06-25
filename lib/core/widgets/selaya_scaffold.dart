import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'geometric_background.dart';
import 'mini_player_chrome.dart';
import 'selaya_bottom_nav.dart';

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
    // Alt menü tutarlılığı: tam-ekran detay rotaları (shell sekmesi DEĞİL +
    // tam-ekran deneyim değil) alt menüyü kaybediyordu. Burada merkezî olarak
    // ekleriz → sekmeye dokununca context.go ile o şubeye gidilir. Shell
    // sekmeleri (_MainShell zaten nav veriyor) ve splash/feed/story gibi
    // tam-ekran ekranlar hariç tutulur.
    String loc = '';
    try {
      loc = GoRouterState.of(context).matchedLocation;
    } catch (_) {}
    final showNav =
        loc.isNotEmpty && !isShellLocation(loc) && !miniHiddenForLocation(loc);
    Widget? bottom = bottomBar;
    if (showNav) {
      final nav = SelayaBottomNav(
        currentIndex: -1, // detay ekranında sekme vurgusu yok
        onTap: (i) => context.go(kNavBranchRoutes[i]),
      );
      bottom = bottomBar == null
          ? nav
          : Column(mainAxisSize: MainAxisSize.min, children: [bottomBar!, nav]);
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.bg,
      floatingActionButton: floatingActionButton,
      // 🎛️ Mini çalarlar artık burada DEĞİL: app.dart'taki
      // GlobalMiniPlayerOverlay tüm rotaların üstünde TEK instance render eder
      // (sekme/sayfa başına kopya yok). Buraya yalnızca sayfanın KENDİ barı
      // gelir (okuyucunun sure kumandası gibi).
      bottomNavigationBar: bottom,
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
