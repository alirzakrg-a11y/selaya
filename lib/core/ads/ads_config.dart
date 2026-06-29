import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../di/providers.dart';

/// AdMob reklam yapılandırması.
///
/// [kUseTestAds] true iken Google'ın RESMÎ TEST reklam birimleri kullanılır
/// (geliştirme/test GÜVENLİ — kendi reklamına tıklamak hesabı engellemez).
/// Play YAYININA hazır olunca `false` yap → gerçek SELAYA birimleri devreye girer.
/// YAYIN LİSTESİ: false yapmadan ÖNCE [kAdsTestDeviceIds]'e kendi test
/// telefonunun hash'ini ekle (logcat "setTestDeviceIds") ki gerçek birimlerle
/// test ederken kendine tıklama / geçersiz trafik riski olmasın.
const bool kUseTestAds = true;

/// Reklam ana anahtarı — false ise hiçbir reklam yüklenmez/gösterilmez.
const bool kAdsEnabled = true;

/// Geliştirici test telefonları (hash). kUseTestAds=false iken bu cihazlarda
/// YİNE test reklamı döner. Hash ilk reklam isteğinde logcat'e yazılır.
const List<String> kAdsTestDeviceIds = <String>[];

/// AdMob SDK başlatıldı + içerik/onay yapılandırması tamam → reklamlar
/// YÜKLENEBİLİR. Banner/native widget'ları bunu dinler (init bitmeden yükleme
/// denemesi başarısız olurdu). main()'de ProviderScope yok → Provider değil
/// sade global ValueNotifier.
final ValueNotifier<bool> adsReady = ValueNotifier<bool>(false);

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

/// AdMob'u GÜVENLİ başlat: (1) içerik derecesini G'ye sabitle (İslami uygulama
/// → alkol/kumar/flört reklamı çıkmasın), (2) UMP/GDPR onayını (AB/İngiltere/
/// İsviçre) iste ve gerekiyorsa formu göster, (3) SDK'yı başlat → [adsReady].
/// Onay AdMob panelinde bir GDPR mesajı oluşturulmasını gerektirir; mesaj yoksa
/// form atlanır ve normal akış sürer.
void initAds() {
  if (!kAdsEnabled) return;
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      maxAdContentRating: MaxAdContentRating.g,
      testDeviceIds: kAdsTestDeviceIds,
    ),
  );
  void start() {
    MobileAds.instance.initialize().then((_) => adsReady.value = true);
  }

  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () => ConsentForm.loadAndShowConsentFormIfRequired((_) => start()),
    (_) => start(),
  );
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
