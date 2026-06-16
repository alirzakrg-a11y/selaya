import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// GLOBAL KÖŞE PLAY DÜĞMESİ KALDIRILDI (kullanıcı 2026-06-15: "Kur'an ve Yâsîn
/// sadece kendi sayfalarında dinlenebilsin, play tuşu başka yerlerde
/// görünmesin"). Oynatma kontrolü artık YALNIZ Kur'an okuyucu + Yâsîn + mushaf
/// alt navigasyonunda. Bu overlay app.dart Stack'inde mount edili kaldığından
/// sınıf duruyor ama hiçbir şey render etmiyor (ses arka planda just_audio +
/// audio_service ile çalmaya devam eder; sadece global düğme yok).
class GlobalMiniPlayerOverlay extends ConsumerWidget {
  const GlobalMiniPlayerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}
