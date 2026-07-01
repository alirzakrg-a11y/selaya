import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../router/routes.dart';

/// Root Navigator'ın key'i — GoRouter bunu kullanır. Global mini çalarlar
/// Navigator ağacının DIŞINDA (app.dart overlay'i) yaşadığından, mini'den
/// açılan now-playing push'ları da bu key üzerinden yapılır.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Tam ekran çalar (now-playing) açık mı? Açıkken global mini gizlenir —
/// üstüne binmesin. Now-playing'ler GoRouter rotası değil (raw Navigator.push)
/// olduğundan location'dan tespit edilemez; open…NowPlaying() fonksiyonları
/// açarken true yazar, route kapanınca (swipe/geri/durdur) false'a döner.
final fullScreenPlayerOpen = ValueNotifier<bool>(false);

/// Kabuk alt navigasyonunun ÖLÇÜLEN yüksekliği (kabuk yazar, overlay okur):
/// sekmelerdeyken mini bu kadar yukarıda — navbar'ın hemen üstünde — durur.
/// Sabit kodlanmaz: textScale (0.9–1.35) + cihaz safe-area'sıyla değişir.
final navBarHeight = ValueNotifier<double>(0);

/// Global mini'nin ÖLÇÜLEN yüksekliği (overlay yazar): Mushaf gibi alt şeridi
/// sabit sayfalar, içerikleri mini altında kalmasın diye bu kadar boşluk
/// bırakır. Mini gizliyken/boşken 0.
final miniPlayerHeight = ValueNotifier<double>(0);

/// Mini'nin HİÇ görünmeyeceği rotalar (tam ekran deneyimler) — tek yerden
/// yönetilir; yeni bir tam ekran rota eklerken buraya da ekle.
const _miniHiddenPrefixes = <String>{
  Routes.splash,
  Routes.intro,
  Routes.onboarding,
  Routes.story, // hikâye görüntüleyici (/story/:index)
  Routes.feed, // tam ekran video akışı (reels)
  Routes.adhanAlarm, // ezan alarmı (/adhan-alarm/:slot)
  // Tebrik kartı editörü: kendi Paylaş/İndir çubuğu var; alt menü + reklam
  // banner'ı düzenleme alanını sıkıştırıp Canva-tarzı araçları gizliyordu.
  Routes.greetings,
};

/// Kabuk sekmeleri — mini, SelayaBottomNav'ın hemen üstünde konumlanır.
const _shellLocations = <String>{
  Routes.home,
  Routes.times,
  Routes.quran,
  Routes.qibla,
  Routes.akis,
  Routes.more,
};

bool miniHiddenForLocation(String location) =>
    _miniHiddenPrefixes.any((p) => location == p || location.startsWith('$p/'));

bool isShellLocation(String location) => _shellLocations.contains(location);

/// Child'ının layout sonrası yüksekliğini [notifier]'a yazar (frame sonunda —
/// layout sırasında notifier tetiklenmez). Navbar + mini ölçümünde kullanılır.
class HeightReporter extends SingleChildRenderObjectWidget {
  final ValueNotifier<double> notifier;
  const HeightReporter(
      {super.key, required this.notifier, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderHeightReporter(notifier);

  @override
  void updateRenderObject(
          BuildContext context, RenderHeightReporter renderObject) =>
      renderObject.notifier = notifier;
}

class RenderHeightReporter extends RenderProxyBox {
  RenderHeightReporter(this.notifier);
  ValueNotifier<double> notifier;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (notifier.value != h) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (notifier.value != h) notifier.value = h;
      });
    }
  }
}
