import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../router/routes.dart';
import 'ads_config.dart';

/// Geçiş (interstitial) reklamı yöneticisi: bir reklamı önceden yükler, belirli
/// sayıda UYGUN ekran geçişinde + zorunlu min. süre aralığıyla bir kez tam-sayfa
/// gösterir. Namaz/Kur'an/zikir gibi akışlar [AdInterstitialObserver]'ın atlama
/// listesiyle sayıma girmez.
class AdsService {
  AdsService(this._ref);
  final Ref _ref;

  InterstitialAd? _ad;
  bool _loading = false;
  bool _showing = false;
  int _count = 0;
  DateTime? _lastShown;

  /// Kaç UYGUN geçişte bir reklam gösterilsin (4-5 arası → 5).
  static const int _everyN = 5;

  /// İki geçiş reklamı arasında ZORUNLU minimum süre (yoğunluk tavanı).
  static const Duration _minGap = Duration(seconds: 60);

  void _preload() {
    if (!kAdsEnabled || _ad != null || _loading) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) => _loading = false,
      ),
    );
  }

  /// Atlama listesi DIŞINDA bir ekran geçişi oldu. Eşik ([_everyN]) aşıldıysa,
  /// reklam hazırsa ve son reklamdan beri [_minGap] geçtiyse (ve premium değil)
  /// geçiş reklamını gösterir; her durumda sonraki reklamı arka planda hazırlar.
  /// Sayaç/gösterim, yükleme durumundan AYRI: reklam hazır değilken eşikte
  /// bekler (no-fill penceresinde taşıp sonraki tek geçişte patlamaz).
  void onEligibleTransition() {
    if (!kAdsEnabled || _showing) return;
    if (!_ref.read(adsActiveProvider)) return; // premium → hiç reklam
    _preload(); // sonraki reklamı daima arka planda hazırla
    _count++;
    if (_count < _everyN) return; // eşik dolmadı
    if (_ad == null) return; // hazır değil → eşikte BEKLE (sayaç sabit kalır)
    final now = DateTime.now();
    if (_lastShown != null && now.difference(_lastShown!) < _minGap) return;
    _count = 0;
    _lastShown = now;
    final ad = _ad!;
    _ad = null;
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        _preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showing = false;
        _preload();
      },
    );
    // show() metod-kanalı hatası fırlatırsa hiçbir callback gelmez → _showing
    // kalıcı true takılıp oturum boyunca reklam durmasın diye try/catch.
    try {
      ad.show();
    } catch (_) {
      ad.dispose();
      _showing = false;
      _preload();
    }
  }
}

final adsServiceProvider = Provider<AdsService>((ref) => AdsService(ref));

/// go_router'a takılan gözlemci: her TAM-SAYFA push'ta (atlama listesi hariç)
/// geçiş reklamı sayacını ilerletir. Sayma için kök-navigatöre push edilen
/// route'ların `name=path` olması gerekir (bkz. app_router `fs()`).
class AdInterstitialObserver extends NavigatorObserver {
  AdInterstitialObserver(this._ref);
  final Ref _ref;

  /// İbadet/okuma/immersive + sistem akışları — geçiş reklamı GÖSTERİLMEZ.
  static const _skip = <String>[
    Routes.splash,
    Routes.intro,
    Routes.onboarding,
    Routes.premium,
    Routes.quranReader,
    Routes.mushaf,
    Routes.dhikr,
    Routes.tesbihat,
    Routes.adhanAlarm,
    Routes.story,
    Routes.qibla,
    Routes.audioStories,
  ];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name;
    if (name == null || name.isEmpty) return; // anonim (dialog/sheet/shell)
    if (_skip.any((s) => name == s || name.startsWith('$s/'))) return;
    _ref.read(adsServiceProvider).onEligibleTransition();
  }
}
