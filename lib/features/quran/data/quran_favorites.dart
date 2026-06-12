import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';

/// Favori sureler (sure numaraları). `PrefKeys.quranBookmarks` ile kalıcı —
/// Kur'an ekranındaki "Favoriler" sekmesiyle AYNI anahtarı kullanır, böylece
/// now-playing ses ekranındaki yıldız (⑦) ile liste tutarlı kalır.
class QuranFavorites extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    final raw = ref
            .read(sharedPreferencesProvider)
            .getStringList(PrefKeys.quranBookmarks) ??
        const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  void toggle(int surah) {
    final next = {...state};
    next.contains(surah) ? next.remove(surah) : next.add(surah);
    state = next;
    ref.read(sharedPreferencesProvider).setStringList(
        PrefKeys.quranBookmarks, next.map((e) => '$e').toList());
  }
}

final quranFavoritesProvider =
    NotifierProvider<QuranFavorites, Set<int>>(QuranFavorites.new);
