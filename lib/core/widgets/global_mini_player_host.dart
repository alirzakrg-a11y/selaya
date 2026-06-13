import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/audio_stories/presentation/audio_story_mini_player.dart';
import '../../features/quran/data/quran_audio_controller.dart';
import '../../features/quran/presentation/quran_mini_player.dart';
import '../router/app_router.dart';
import 'mini_player_chrome.dart';

/// İki global mini çaları saran TEK host — uygulamada yalnızca app.dart'taki
/// [GlobalMiniPlayerOverlay] içinde bir kez mount edilir (sekme/sayfa başına
/// kopya yok). Mini'lerin kendi görünürlük kuralları (mode-guard: yalnız kendi
/// sesi çalarken görünme) aynen kendi içlerinde.
class GlobalMiniPlayerHost extends StatelessWidget {
  /// Okuyucu, çalan surenin KENDİ kumandasını gösterirken Kur'an mini'si
  /// gizlenir — çift kumanda olmasın (hikâye mini'si etkilenmez).
  final bool hideQuranMini;
  const GlobalMiniPlayerHost({super.key, this.hideQuranMini = false});

  @override
  Widget build(BuildContext context) {
    // Overlay, Navigator/Scaffold dışında yaşar → IconButton ink'leri için
    // Material atasını burada sağlarız.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hideQuranMini) const QuranMiniPlayer(),
          const AudioStoryMiniPlayer(),
        ],
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
    // Okuyucu "çalan sureyi" gösterirken kendi kumandası çıkar → Kur'an
    // mini'sini orada gizleyeceğiz (çift kumanda olmasın).
    final playingSurah = ref.watch(
        quranAudioControllerProvider.select((s) => s.surahNumber));
    return ListenableBuilder(
      // routerDelegate her navigasyonda bildirir → location'a göre konum/gizlilik.
      listenable: Listenable.merge(
          [router.routerDelegate, fullScreenPlayerOpen, navBarHeight]),
      builder: (context, _) {
        // DİKKAT: uri.path DEĞİL — push'lanan rotalarda uri güncellenmez.
        final location =
            topRouteLocation(router.routerDelegate.currentConfiguration);
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
        // Kur'an mini'si SADECE Kur'an bölümünde (sekme + okuyucu + Yâsîn +
        // Mushaf) görünür → Ana Sayfa/Vakitler/Kıble/Akış/Daha Fazla'da ses
        // çalarken bile HİÇ render edilmez (kullanıcı isteği + "komple donma"
        // fix'i: her sekmenin üstündeki global çizim yükünü kaldır; ses
        // audio_service ile arka planda devam eder, kumanda bildirimde). Ayrıca
        // okuyucu çalan sureyi gösterirken kendi kumandası çıktığından orada da
        // gizli (çift kumanda olmasın).
        final hideQuranMini = !isQuranSectionLocation(location) ||
            (playingSurah != null && quranReaderSurah(location) == playingSurah);
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: HeightReporter(
              notifier: miniPlayerHeight,
              child: GlobalMiniPlayerHost(hideQuranMini: hideQuranMini),
            ),
          ),
        );
      },
    );
  }
}
