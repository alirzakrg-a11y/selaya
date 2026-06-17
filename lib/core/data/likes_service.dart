import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/cdn.dart';
import '../di/providers.dart';

/// Deterministik "rastgele" beğeni tabanı — içerik popüler görünsün diye (anahtara
/// göre SABİT, her cihazda/kullanıcıda AYNI). Gerçek beğeniler (sunucu) bunun
/// ÜSTÜNE eklenir, böylece sayı beğendikçe artar.
int likeSeed(String key) {
  var h = 2166136261;
  for (final code in key.codeUnits) {
    h = ((h ^ code) * 16777619) & 0x7fffffff;
  }
  return 40 + (h % 4760); // 40..4799 arası sabit taban
}

/// Sunucudaki beğeni sayıları (key → count). Açılışta `/v1/likes`'tan çekilir ve
/// prefs'te önbeklenir (offline'da son bilinen sayılar gösterilir). Beğeni
/// sayıları sunucuda tutulur; ileride "kim beğendi" da buraya eklenebilir.
final likesProvider = FutureProvider<Map<String, int>>((ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  Map<String, int> cached = {};
  final raw = prefs.getString(PrefKeys.likesCache);
  if (raw != null) {
    try {
      cached = (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      );
    } catch (_) {}
  }
  try {
    final res = await http
        .get(Uri.parse('${SelayaCdn.apiBase}/v1/likes'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final likes = (data['likes'] as Map?) ?? const {};
      final map = likes.map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      );
      await prefs.setString(PrefKeys.likesCache, jsonEncode(map));
      return map;
    }
  } catch (_) {}
  return cached;
});

/// Kullanıcının yerel olarak beğendiği anahtarlar — kalp dolu kalsın ve tekrar
/// beğeni engellensin. prefs'te saklanır.
class LikedKeys extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      (ref.read(sharedPreferencesProvider).getStringList(PrefKeys.likedKeys) ??
              const [])
          .toSet();

  bool has(String key) => state.contains(key);

  /// Beğeni AÇ/KAPA (çift yönlü): yerelde işaretle/kaldır + sunucuya +1/−1 gönder.
  /// Dolu kalbe tekrar dokununca beğeni geri alınır (kalp boşalır, panelde −1).
  Future<void> toggle(String key) async {
    final wasLiked = state.contains(key);
    final next = wasLiked
        ? (state.where((k) => k != key).toSet())
        : {...state, key};
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(PrefKeys.likedKeys, next.toList());
    try {
      final action = wasLiked ? 'unlike' : 'like';
      await http
          .post(
            Uri.parse(
              '${SelayaCdn.apiBase}/v1/$action/${Uri.encodeComponent(key)}',
            ),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}

final likedKeysProvider = NotifierProvider<LikedKeys, Set<String>>(
  LikedKeys.new,
);
