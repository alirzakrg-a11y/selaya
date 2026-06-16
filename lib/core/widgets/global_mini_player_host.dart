import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/quran/data/quran_audio_controller.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'mini_player_chrome.dart';

/// MİNİ PLAYER KALDIRILDI (kullanıcı 2026-06-15): eski tam-genişlik alt şerit
/// (sure adı + ilerleme + ⏮⏯⏭⏹ + yukarı-kaydır→tam ekran) komple çıkarıldı.
/// Yerine YALNIZCA köşede sade bir oynat/durdur düğmesi: Kur'an sesi çalarken
/// sağ-altta görünür, dokun = başlat/durdur (play/pause), uzun bas = tamamen
/// durdur. Yukarı-kaydır / tam ekran çalar AÇILMAZ.
///
/// Root Navigator'ın ÜSTÜNDE yaşar (app.dart builder'ında Stack ile mount). Tam
/// ekran deneyimlerde ([miniHiddenForLocation]) ve tam ekran çalar açıkken
/// gizlenir.
class GlobalMiniPlayerOverlay extends ConsumerWidget {
  const GlobalMiniPlayerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return ListenableBuilder(
      // routerDelegate her navigasyonda bildirir → location'a göre gizlilik/konum.
      listenable: Listenable.merge(
          [router.routerDelegate, fullScreenPlayerOpen, navBarHeight]),
      builder: (context, _) {
        final location = router.routerDelegate.currentConfiguration.uri.path;
        if (fullScreenPlayerOpen.value || miniHiddenForLocation(location)) {
          return const SizedBox.shrink();
        }
        // Kabuk sekmelerinde alt navigasyonun hemen üstünde, push'lanan detay
        // rotalarında safe-area'nın üstünde dursun.
        final bottom = isShellLocation(location)
            ? navBarHeight.value
            : MediaQuery.viewPaddingOf(context).bottom;
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
                bottom: bottom + AppSpacing.md, right: AppSpacing.base),
            child: const _CornerPlayButton(),
          ),
        );
      },
    );
  }
}

/// Sade köşe oynat/durdur düğmesi — yalnız Kur'an sesi yüklüyken görünür.
/// Dokun: başlat/durdur. Uzun bas: tamamen durdur (kuyruğu kapatır).
class _CornerPlayButton extends ConsumerWidget {
  const _CornerPlayButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(quranAudioControllerProvider);
    final ctrl = ref.read(quranAudioControllerProvider.notifier);
    // Ses yüklü değilse (sure seçilmemiş) veya başka mod çalıyorsa → görünme.
    if (st.surahNumber == null || !ctrl.isQuranMode) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    return Material(
      color: c.gold,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black54,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: ctrl.toggle, // başlat / durdur
        onLongPress: ctrl.stop, // tamamen durdur
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            st.loading
                ? Icons.hourglass_bottom_rounded
                : (st.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded),
            color: c.bg,
            size: 32,
          ),
        ),
      ),
    );
  }
}
