import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/likes_service.dart';
import '../../../core/di/providers.dart';
import '../../hatim/data/hatim_controller.dart';
import '../../hatim/domain/hatim_session.dart';
import '../../home/data/home_layout_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import 'auth_api.dart';
import 'auth_controller.dart';

/// Senkron durumu (UI için).
class SyncState {
  final bool syncing;
  final int lastSyncedAt; // ms epoch, 0 = hiç
  final String? error; // hata kodu
  const SyncState({this.syncing = false, this.lastSyncedAt = 0, this.error});
}

/// Hangi PrefKeys buluta senkronlanır? (Kişisel veri; cihaza-özel + gizli olanlar HARİÇ.)
class _Scope {
  static const exact = <String>{
    PrefKeys.quranBookmarks,
    PrefKeys.duaFavorites,
    PrefKeys.inspirationFavorites,
    PrefKeys.quranLastRead, PrefKeys.dhikrCustom,
    PrefKeys.kazaCounts, PrefKeys.kazaCompleted, PrefKeys.homeOrder,
    PrefKeys.homeHidden, PrefKeys.featuredOrder, PrefKeys.featuredHidden,
    PrefKeys.dailyTasksLog, PrefKeys.likedKeys, PrefKeys.prayerOffsets,
    PrefKeys.hanafiAsr, PrefKeys.hijriOffsetDays, PrefKeys.themeMode,
    PrefKeys.amoled, PrefKeys.palette, PrefKeys.textScale,
    // Hatim: push/pull normal taşır; restore'da readPagesByDay GÜN GÜN merge
    // edilir (mergeHatimData) — overwrite değil.
    PrefKeys.hatimState,
  };
  static const prefixes = <String>['tracking_', 'fasting_', 'dhikr_total_'];

  static bool match(String k) {
    // Gizli/cihaza-özel: kadın modu (KVKK sağlık verisi), oturum token'ı.
    if (k.startsWith('womens') ||
        k == PrefKeys.authToken ||
        k == PrefKeys.authUser ||
        k == PrefKeys.lastSyncAt) {
      return false;
    }
    return exact.contains(k) || prefixes.any(k.startsWith);
  }
}

class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() => SyncState(
    lastSyncedAt:
        ref.read(sharedPreferencesProvider).getInt(PrefKeys.lastSyncAt) ?? 0,
  );

  // prefs -> json (her değer {t,v} ile tipiyle sarılır)
  Map<String, dynamic> _collect() {
    final prefs = ref.read(sharedPreferencesProvider);
    final out = <String, dynamic>{};
    for (final k in prefs.getKeys()) {
      if (!_Scope.match(k)) continue;
      final v = prefs.get(k);
      if (v is List) {
        out[k] = {'t': 'sl', 'v': v.map((e) => e.toString()).toList()};
      } else if (v is String) {
        out[k] = {'t': 's', 'v': v};
      } else if (v is bool) {
        out[k] = {'t': 'b', 'v': v};
      } else if (v is int) {
        out[k] = {'t': 'i', 'v': v};
      } else if (v is double) {
        out[k] = {'t': 'd', 'v': v};
      }
    }
    return out;
  }

  // json -> prefs
  Future<void> _apply(Map<String, dynamic> data) async {
    final prefs = ref.read(sharedPreferencesProvider);
    for (final e in data.entries) {
      if (!_Scope.match(e.key)) continue;
      final w = e.value;
      if (w is! Map) continue;
      final v = w['v'];
      try {
        switch (w['t']) {
          case 'sl':
            await prefs.setStringList(
              e.key,
              (v as List).map((x) => x.toString()).toList(),
            );
            break;
          case 's':
            await prefs.setString(e.key, v.toString());
            break;
          case 'b':
            await prefs.setBool(e.key, v == true);
            break;
          case 'i':
            await prefs.setInt(e.key, (v as num).toInt());
            break;
          case 'd':
            await prefs.setDouble(e.key, (v as num).toDouble());
            break;
        }
      } catch (_) {}
    }
  }

  String _device() => defaultTargetPlatform.name;
  String _code(Object e) => e is AuthException ? e.code : 'unknown';

  Future<void> _stamp() async {
    await ref
        .read(sharedPreferencesProvider)
        .setInt(PrefKeys.lastSyncAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Giriş/kayıt veya manuel: buluttan çek + birleştir (bulut çakışmada kazanır)
  /// + birleşimi geri yükle. "Yeni cihazda verilerim geldi" anı.
  Future<void> restore() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.loggedIn || state.syncing) return;
    state = SyncState(syncing: true, lastSyncedAt: state.lastSyncedAt);
    final prefs = ref.read(sharedPreferencesProvider);
    // Hatim'i _clearLocal SİLMEDEN önce yakala → bulut uygulandıktan sonra
    // readPagesByDay'i gün gün geri kat (overwrite değil, union).
    final localHatim = prefs.getString(PrefKeys.hatimState);
    try {
      final remote = await AuthApi.getData(auth.token!);
      if (remote.data.isNotEmpty) {
        // Mevcut hesap → SADECE bu hesabın verisi görünsün: yereli temizle + bulutu yükle
        // (önceki kullanıcının/misafirin verisiyle KARIŞMASIN).
        await _clearLocal();
        await _apply(remote.data);
        // Hatim: yerel (merge öncesi) + bulut = gün-union; currentPage = max.
        final merged = mergeHatimData(
          HatimData.decode(localHatim),
          HatimData.decode(prefs.getString(PrefKeys.hatimState)),
        );
        await prefs.setString(PrefKeys.hatimState, merged.encode());
      } else {
        // Yeni/boş hesap → mevcut yerel (misafir) veriyi hesaba yükle (seed).
        await AuthApi.putData(auth.token!, _collect(), _device());
      }
      await _stamp();
      _refresh();
      state = SyncState(
        syncing: false,
        lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      state = SyncState(
        syncing: false,
        lastSyncedAt: state.lastSyncedAt,
        error: _code(e),
      );
    }
  }

  /// Yerel değişiklikleri buluta gönder (lifecycle pause — sessiz).
  Future<void> push() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.loggedIn || state.syncing) return;
    try {
      await AuthApi.putData(auth.token!, _collect(), _device());
      await _stamp();
      state = SyncState(
        syncing: false,
        lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // sessiz: bir sonraki fırsatta tekrar denenir
    }
  }

  // Senkronlanan TÜM yerel anahtarı sil → ilk ayarlara dön (çıkış / hesap değişimi).
  Future<void> _clearLocal() async {
    final prefs = ref.read(sharedPreferencesProvider);
    for (final k in prefs.getKeys().where(_Scope.match).toList()) {
      await prefs.remove(k);
    }
  }

  /// Çıkışta çağrılır: yereldeki hesap verisini temizle + provider'ları tazele
  /// (uygulama ilk ayarlara/varsayılana döner; veri zaten bulutta güvende).
  Future<void> resetLocal() async {
    await _clearLocal();
    await ref.read(sharedPreferencesProvider).remove(PrefKeys.lastSyncAt);
    _refresh();
    state = const SyncState();
  }

  void _refresh() {
    // Uygulanan veriyi önbellekleyen global provider'ları tazele (tema, düzen,
    // beğeni). Ekran-yerel veriler (oruç/ibadet/favori/zikir) o ekrana girince
    // prefs'i taze okur — ek tazeleme gerekmez.
    ref.invalidate(likedKeysProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(homeLayoutProvider);
    ref.invalidate(hatimControllerProvider);
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);
