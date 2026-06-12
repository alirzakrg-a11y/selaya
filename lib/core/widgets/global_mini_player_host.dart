import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/audio_stories/presentation/audio_story_mini_player.dart';
import '../../features/quran/presentation/quran_mini_player.dart';
import '../router/app_router.dart';
import 'mini_player_chrome.dart';

/// İki global mini çaları saran TEK host — uygulamada yalnızca app.dart'taki
/// [GlobalMiniPlayerOverlay] içinde bir kez mount edilir (sekme/sayfa başına
/// kopya yok). Mini'lerin kendi görünürlük kuralları (mode-guard: yalnız kendi
/// sesi çalarken görünme) aynen kendi içlerinde.
class GlobalMiniPlayerHost extends StatelessWidget {
  const GlobalMiniPlayerHost({super.key});

  @override
  Widget build(BuildContext context) {
    // Overlay, Navigator/Scaffold dışında yaşar → IconButton ink'leri için
    // Material atasını burada sağlarız.
    return const Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [QuranMiniPlayer(), AudioStoryMiniPlayer()],
      ),
    );
  }
}

/// Root Navigator'ın ÜSTÜNDE yaşayan global mini katmanı (app.dart builder'ında
/// Stack ile mount edilir) — ses çalarken kumanda TÜM rotalarda görünür. Konum:
///  • kabuk sekmeleri → SelayaBottomNav'ın hemen üstü (ölçülen [navBarHeight]),
///  • push'lanan detay rotaları → ekranın altı (safe-area'ya saygılı),
///  • [miniHiddenForLocation] rotaları + tam ekran çalar açıkken → render yok.
/// Klavye: konum viewPadding'e bağlı (viewInsets değil) → mini klavyeyle yukarı
/// zıplamaz; klavye onu örter (eski bottomNavigationBar davranışıyla aynı).
class GlobalMiniPlayerOverlay extends ConsumerWidget {
  const GlobalMiniPlayerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return ListenableBuilder(
      // routerDelegate her navigasyonda bildirir → location'a göre konum/gizlilik.
      listenable: Listenable.merge(
          [router.routerDelegate, fullScreenPlayerOpen, navBarHeight]),
      builder: (context, _) {
        final location = router.routerDelegate.currentConfiguration.uri.path;
        final hidden =
            fullScreenPlayerOpen.value || miniHiddenForLocation(location);
        if (hidden) {
          // Host render edilmiyor → içerik boşluğu hesabı (Mushaf) sıfırlansın.
          if (miniPlayerHeight.value != 0) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => miniPlayerHeight.value = 0);
          }
          return const SizedBox.shrink();
        }
        final bottom = isShellLocation(location)
            ? navBarHeight.value
            : MediaQuery.viewPaddingOf(context).bottom;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: HeightReporter(
              notifier: miniPlayerHeight,
              child: const GlobalMiniPlayerHost(),
            ),
          ),
        );
      },
    );
  }
}
