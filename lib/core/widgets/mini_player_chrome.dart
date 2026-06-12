import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

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

/// Kabuk alanında mıyız? Sekme kökleri VE altlarına yuvalanmış rotalar
/// (örn. /quran/reader/36) — hepsinde alt menü görünür, mini onun üstünde.
bool isShellLocation(String location) =>
    _shellLocations.any((p) => location == p || location.startsWith('$p/'));

/// Rotayı doğru şekilde açar: kabuk-altı hedefe `go` (doğru sekmeye geçer,
/// alt menü görünür kalır — başka sekmeden/push'lu sayfadan da çalışır),
/// tam ekran hedefe `push`. Menü/kart gibi genel açıcılar bunu kullanır.
void openRoute(BuildContext context, String route) {
  if (isShellLocation(route)) {
    GoRouter.of(context).go(route);
  } else {
    GoRouter.of(context).push(route);
  }
}

/// GoRouter konfigürasyonundaki EN ÜSTTEKİ yaprak rotanın konumu.
/// `currentConfiguration.uri` context.push ile açılan rotalarda DEĞİŞMEZ
/// (go_router tasarımı: push URL'yi güncellemez) → uri.path kullanmak tüm
/// detay sayfalarını kabuk sanma hatası doğuruyordu (cihazda görüldü). Shell
/// zincirini açıp imperative push'lar dahil gerçek üst rotayı döndürür.
String topRouteLocation(RouteMatchList configuration) {
  if (configuration.matches.isEmpty) return '';
  RouteMatchBase match = configuration.matches.last;
  while (match is ShellRouteMatch) {
    match = match.matches.last;
  }
  return match.matchedLocation;
}

/// Konum bir Kur'an okuyucusuysa gösterdiği sure numarası (değilse null).
/// Okuyucu, ÇALAN sureyi gösterirken kendi alt kumandasını kuruyor — global
/// Kur'an mini'si o ekranda gizlenir ki çift kumanda olmasın (hikâye mini'si
/// etkilenmez). Eski `bottomBar ?? mini` ilişkisinin overlay karşılığı.
int? quranReaderSurah(String location) {
  if (location == Routes.yasin) return 36;
  final prefix = '${Routes.quranReader}/';
  if (!location.startsWith(prefix)) return null;
  final raw = location.substring(prefix.length);
  return int.tryParse(raw.split('/').first.split('?').first);
}

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
