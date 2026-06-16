import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_icons.dart';

class FeaturedTool {
  final IconData icon;
  final String labelKey;
  final String route;
  const FeaturedTool(this.icon, this.labelKey, this.route);
}

/// "Öne Çıkanlar" ızgarasında kullanılabilecek TÜM araçlar (anahtar → araç).
const featuredTools = <String, FeaturedTool>{
  'tracking': FeaturedTool(AppIcons.chart, 'tracking.title', Routes.tracking),
  'asma': FeaturedTool(AppIcons.crown, 'asma.title', Routes.asma),
  'duas': FeaturedTool(AppIcons.dua, 'duas.title', Routes.duas),
  'mosques': FeaturedTool(AppIcons.mosque, 'mosques.title', Routes.mosques),
  'calendar': FeaturedTool(AppIcons.calendar, 'calendar.title', Routes.calendar),
  'imsakiye':
      FeaturedTool(Icons.wb_twilight_rounded, 'imsakiye.title', Routes.imsakiye),
  'quran': FeaturedTool(AppIcons.quran, 'quran.title', Routes.quran),
  'dhikr': FeaturedTool(AppIcons.tasbih, 'dhikr.title', Routes.dhikr),
  'ai': FeaturedTool(AppIcons.aiMagic, 'ai.title', Routes.ai),
  'wallpaper':
      FeaturedTool(AppIcons.wallpaper, 'wallpapers.title', Routes.wallpapers),
  'kaza': FeaturedTool(AppIcons.history, 'kaza.title', Routes.kaza),
  'greetings': FeaturedTool(AppIcons.card, 'greetings.title', Routes.greetings),
  // Varsayılan gizli — kullanıcı ekleyebilir:
  'qibla': FeaturedTool(AppIcons.qibla, 'qibla.title', Routes.qibla),
  'yasin': FeaturedTool(AppIcons.book, 'more.yasin', Routes.yasin),
  'fasting': FeaturedTool(AppIcons.fasting, 'fasting.title', Routes.fasting),
  'hatim':
      FeaturedTool(Icons.auto_stories_rounded, 'hatim.title', Routes.hatim),
  'widgets': FeaturedTool(
      AppIcons.tune, 'widgetsGallery.title', Routes.widgetsGallery),
  'abdest': FeaturedTool(
      Icons.water_drop_rounded, 'more.abdestGuide', Routes.abdestGuide),
  'namaz': FeaturedTool(
      Icons.self_improvement_rounded, 'more.namazGuide', Routes.namazGuide),
};

/// Varsayılan sıra (tüm anahtarlar).
const featuredToolKeys = [
  // Öne Çıkanlar — kullanıcının istediği görünür 12 (4x3):
  'dhikr', 'imsakiye', 'quran', 'yasin', 'duas', 'asma',
  'tracking', 'kaza', 'mosques', 'wallpaper', 'calendar',
  // Gerisi (varsayılan gizli — Daha Fazla'da görünür):
  'hatim', 'ai', 'greetings', 'qibla', 'fasting', 'widgets',
  'abdest', 'namaz',
];

/// Varsayılan gizli (ilk 12 görünür, gerisi kullanıcı eklerse).
const _defaultHidden = {
  'hatim',
  'ai',
  'greetings',
  'qibla',
  'fasting',
  'tasks',
  'widgets',
  'abdest',
  'namaz',
};

class FeaturedTools {
  final List<String> order;
  final Set<String> hidden;
  const FeaturedTools(this.order, this.hidden);
  List<String> get visible =>
      order.where((k) => !hidden.contains(k)).toList(growable: false);
  bool isVisible(String k) => !hidden.contains(k);
}

class FeaturedToolsController extends Notifier<FeaturedTools> {
  @override
  FeaturedTools build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getStringList(PrefKeys.featuredOrder);
    final savedHidden = prefs.getStringList(PrefKeys.featuredHidden);
    final hidden = (savedHidden ?? _defaultHidden.toList()).toSet();
    final order = <String>[];
    if (saved != null) {
      for (final k in saved) {
        if (featuredTools.containsKey(k) && !order.contains(k)) order.add(k);
      }
    }
    // Eksik araçları varsayılan komşusunun yanına ekle (ileri uyumlu).
    for (var i = 0; i < featuredToolKeys.length; i++) {
      final k = featuredToolKeys[i];
      if (order.contains(k)) continue;
      var at = 0;
      for (var j = i - 1; j >= 0; j--) {
        final p = order.indexOf(featuredToolKeys[j]);
        if (p >= 0) {
          at = p + 1;
          break;
        }
      }
      order.insert(at, k);
    }
    return FeaturedTools(order, hidden);
  }

  Future<void> _persist(FeaturedTools t) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(PrefKeys.featuredOrder, t.order);
    await prefs.setStringList(PrefKeys.featuredHidden, t.hidden.toList());
    state = t;
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final order = [...state.order];
    if (newIndex > oldIndex) newIndex -= 1;
    order.insert(newIndex, order.removeAt(oldIndex));
    await _persist(FeaturedTools(order, state.hidden));
  }

  Future<void> toggle(String key) async {
    final hidden = {...state.hidden};
    hidden.contains(key) ? hidden.remove(key) : hidden.add(key);
    await _persist(FeaturedTools(state.order, hidden));
  }

  /// Varsayılana dön — sıra + gizlileri sıfırla.
  Future<void> reset() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(PrefKeys.featuredOrder);
    await prefs.remove(PrefKeys.featuredHidden);
    state = FeaturedTools(List.of(featuredToolKeys), Set.of(_defaultHidden));
  }
}

final featuredToolsProvider =
    NotifierProvider<FeaturedToolsController, FeaturedTools>(
        FeaturedToolsController.new);
