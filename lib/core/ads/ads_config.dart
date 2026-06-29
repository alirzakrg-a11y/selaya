import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';

/// AdMob reklam yapılandırması.
///
/// [kUseTestAds] true iken Google'ın RESMÎ TEST reklam birimleri kullanılır
/// (geliştirme/test GÜVENLİ — kendi reklamına tıklamak hesabı engellemez).
/// Play YAYININA hazır olunca `false` yap → gerçek SELAYA birimleri devreye girer.
const bool kUseTestAds = true;

/// Reklam ana anahtarı — false ise hiçbir reklam yüklenmez/gösterilmez.
const bool kAdsEnabled = true;

/// AdMob reklam birimi ID'leri (GİZLİ DEĞİL — apk'ye gömülür, herkese görünür).
class AdIds {
  // Google resmî TEST birimleri.
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testNative = 'ca-app-pub-3940256099942544/2247696110';
  // GERÇEK SELAYA birimleri (kUseTestAds=false olunca devreye girer).
  static const _banner = 'ca-app-pub-5462166590735357/3577939461';
  static const _interstitial = 'ca-app-pub-5462166590735357/6076110295';
  static const _native = 'ca-app-pub-5462166590735357/8246556601';

  static String get banner => kUseTestAds ? _testBanner : _banner;
  static String get interstitial =>
      kUseTestAds ? _testInterstitial : _interstitial;
  static String get native => kUseTestAds ? _testNative : _native;
}

/// Premium (reklamsız) durumu — şimdilik yerel bayrak (gerçek satın-alma sonra
/// bu bayrağı set eder). Premium kullanıcıda hiç reklam gösterilmez.
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(sharedPreferencesProvider).getBool(PrefKeys.isPremium) ??
      false;
});

/// Reklam gösterilsin mi: ana anahtar AÇIK + kullanıcı premium DEĞİL.
final adsActiveProvider = Provider<bool>((ref) {
  return kAdsEnabled && !ref.watch(isPremiumProvider);
});
