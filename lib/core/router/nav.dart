import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../widgets/mini_player_chrome.dart';

extension AppNav on BuildContext {
  /// Alt-menü (shell) sekmesi — Kıble / Vakitler / Akış / Ana Sayfa / Kur'an /
  /// Daha Fazla — `push` edilince go_router'da AÇILMAZ (StatefulShellBranch
  /// rotaları root navigatöre push edilemez). Bu yardımcı shell rotalarını
  /// sekme değiştirerek (go), diğerlerini normal sayfa olarak (push) açar.
  void openRoute(String route) =>
      isShellLocation(route) ? go(route) : push(route);
}
