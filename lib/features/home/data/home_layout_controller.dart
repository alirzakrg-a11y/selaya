import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';

/// Ana ekranda kullanıcının taşıyıp (sürükle) gizleyebildiği opsiyonel
/// bölümler — varsayılan sırasıyla. Üst kısım (selam, geri sayım, vakit şeridi)
/// sabittir; aşağıdaki bölümler kişiselleştirilebilir.
const homeSectionKeys = [
  'storyRail',
  'greeting',
  'religiousDay',
  'gaugeCarousel',
  'prayerStrip',
  'nearestMosque',
  'featured',
  'babyNames', // tek-satır "Bebek İsimleri" kartı
  'quiz', // İslami Bilgi Yarışması kartı
  'audioStories', // Sesli Dini Hikâyeler (TR-only; diğer dillerde boş döner)
  'verseOfDay', // Günün Ayeti — sesli hikâyelerin ALTINDA (kullanıcı isteği)
  'hadithOfDay', // Günün Hadisi — sesli hikâyelerin ALTINDA
  'dailyDua', // Günün Duası — sesli hikâyelerin ALTINDA
  'quickPair',
  'mediaPair', // Videolar + Duvar Kâğıdı YAN YANA (eski videos+wallpaper)
  'widgetPromo',
];
// ⑲ 'inspiration' (Günün İlhamı) anasayfadan KALDIRILDI → yerine 'dailyDua'
// (Günün Duası) kalıyor; ilham içeriği zaten Akış'ta gösteriliyor.

/// Düzenleme menüsünde gösterilecek etiket anahtarı (mevcut çevirilerden).
const homeSectionLabels = {
  'storyRail': 'home.secStories',
  'greeting': 'home.secGreeting',
  'religiousDay': 'home.secReligiousDay',
  'gaugeCarousel': 'home.secCountdown',
  'prayerStrip': 'home.secPrayerStrip',
  'nearestMosque': 'home.nearestMosque',
  'featured': 'home.featured',
  'babyNames': 'babyNames.title',
  'quiz': 'quiz.title',
  'audioStories': 'audioStories.title',
  'verseOfDay': 'akis.verseOfDay',
  'hadithOfDay': 'akis.hadithOfDay',
  'dailyDua': 'akis.duaOfDay',
  'mediaPair': 'home.secMedia',
  'quickPair': 'home.quickPair',
  'widgetPromo': 'home.addWidgetTitle',
};

class HomeLayout {
  final List<String> order;
  final Set<String> hidden;
  const HomeLayout(this.order, this.hidden);

  List<String> get visible =>
      order.where((k) => !hidden.contains(k)).toList(growable: false);
  bool isVisible(String k) => !hidden.contains(k);
}

class HomeLayoutController extends Notifier<HomeLayout> {
  @override
  HomeLayout build() {
    final prefs = ref.read(sharedPreferencesProvider);
    // TEK SEFERLİK: eski/karışık kayıtlı ana-sayfa sırasını temiz varsayılana
    // SIFIRLA (kullanıcı "sıralama bozuk" dedi; yıllarca merge ile birikmiş
    // karışıklık). Manuel ↻ gerekmesin diye güncellemede otomatik uygulanır.
    if (!(prefs.getBool('home_layout_reset_v3') ?? false)) {
      prefs.setBool('home_layout_reset_v3', true);
      prefs.remove(PrefKeys.homeOrder);
      prefs.remove(PrefKeys.homeHidden);
      return HomeLayout(List.of(homeSectionKeys), <String>{});
    }
    final saved = prefs.getStringList(PrefKeys.homeOrder);
    final hidden =
        (prefs.getStringList(PrefKeys.homeHidden) ?? const []).toSet();
    // Kayıtlı sıra + sonradan eklenen yeni bölümler (sona) — ileri uyumlu.
    final order = <String>[];
    if (saved != null) {
      for (final k in saved) {
        if (homeSectionKeys.contains(k) && !order.contains(k)) order.add(k);
      }
    }
    // Eksik (yeni eklenen) bölümleri SONA değil, varsayılan komşusunun yanına
    // yerleştir — böylece güncelleme sonrası yeni kartlar doğru konumda çıkar.
    for (var i = 0; i < homeSectionKeys.length; i++) {
      final k = homeSectionKeys[i];
      if (order.contains(k)) continue;
      var at = 0;
      for (var j = i - 1; j >= 0; j--) {
        final p = order.indexOf(homeSectionKeys[j]);
        if (p >= 0) {
          at = p + 1;
          break;
        }
      }
      order.insert(at, k);
    }
    return HomeLayout(order, hidden);
  }

  Future<void> _persist(HomeLayout l) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(PrefKeys.homeOrder, l.order);
    await prefs.setStringList(PrefKeys.homeHidden, l.hidden.toList());
    state = l;
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final order = [...state.order];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    await _persist(HomeLayout(order, state.hidden));
  }

  Future<void> toggle(String key) async {
    final hidden = {...state.hidden};
    hidden.contains(key) ? hidden.remove(key) : hidden.add(key);
    await _persist(HomeLayout(state.order, hidden));
  }

  /// Varsayılana dön — sıra + gizlileri sıfırla.
  Future<void> reset() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(PrefKeys.homeOrder);
    await prefs.remove(PrefKeys.homeHidden);
    state = HomeLayout(List.of(homeSectionKeys), <String>{});
  }
}

final homeLayoutProvider =
    NotifierProvider<HomeLayoutController, HomeLayout>(HomeLayoutController.new);
