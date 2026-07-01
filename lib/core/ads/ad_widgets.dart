import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';

/// İçerik ekranlarının altına konan **banner reklam**.
///
/// [adsActiveProvider] kapalıysa (ana anahtar / premium) hiç yer kaplamaz. AdMob
/// SDK hazır ([adsReady]) olana ve reklam yüklenene kadar da yer kaplamaz
/// (layout zıplamasın). Her örnek kendi reklamını yükler ve dispose'da bırakır.
class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key});

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    adsReady.addListener(_maybeLoad); // init geç tamamlanırsa yükle
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  void _maybeLoad() {
    if (!mounted || _ad != null) return;
    if (!adsReady.value || !ref.read(adsActiveProvider)) {
      debugPrint(
          'AdBanner._maybeLoad() atlandı: adsReady=${adsReady.value}, '
          'adsActive=${ref.read(adsActiveProvider)}, isPremium=${ref.read(isPremiumProvider)}');
      return;
    }
    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null; // dangling/disposed referans bırakma
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    adsReady.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Premium iptal/bitince (adsActive false→true) banner'ı yeniden yükle —
    // yoksa reklamlar ancak ekran/State yeniden kurulunca (≈2 açılış) geri gelir.
    ref.listen<bool>(adsActiveProvider, (prev, next) {
      if (next) _maybeLoad();
    });
    final ad = _ad;
    if (!ref.watch(adsActiveProvider) || !_loaded || ad == null) {
      return const SizedBox.shrink();
    }
    // RepaintBoundary: platform-view (texture) katmanını izole et → alt menünün
    // (aktif sekme AnimatedScale vb.) yeniden çizimleri banner'ı kirletmesin.
    return RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

/// İçeriğin akışına gömülen **yerel (native) reklam kartı** — ana sayfada.
/// AdMob "medium" şablonu kullanır (platform factory GEREKMEZ). adsActive/
/// adsReady değilse hiç yer kaplamaz.
class NativeAdCard extends ConsumerStatefulWidget {
  const NativeAdCard({super.key});

  @override
  ConsumerState<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends ConsumerState<NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    adsReady.addListener(_maybeLoad);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  void _maybeLoad() {
    if (!mounted || _ad != null) return;
    if (!adsReady.value || !ref.read(adsActiveProvider)) {
      debugPrint(
          'NativeAdCard._maybeLoad() atlandı: adsReady=${adsReady.value}, '
          'adsActive=${ref.read(adsActiveProvider)}, isPremium=${ref.read(isPremiumProvider)}');
      return;
    }
    final ad = NativeAd(
      adUnitId: AdIds.native,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null;
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    adsReady.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Premium iptal/bitince (adsActive false→true) native reklamı yeniden yükle.
    ref.listen<bool>(adsActiveProvider, (prev, next) {
      if (next) _maybeLoad();
    });
    final ad = _ad;
    if (!ref.watch(adsActiveProvider) || !_loaded || ad == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 320, maxHeight: 360),
        child: RepaintBoundary(child: AdWidget(ad: ad)),
      ),
    );
  }
}
