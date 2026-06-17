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
    // Namaz vakti hesap yöntemi + mushaf son sayfa (kullanıcı 2026-06-17).
    PrefKeys.calcMethod, PrefKeys.mushafLastPage,
    // Bildirim/ezan tercihleri (kullanıcı 2026-06-17) — KONUM senkronlanmaz, ama
    // hangi vakit/ezan/titreşim/sessize-alma açık BİLGİSİ cihazlar arası taşınır.
    PrefKeys.prayerNotifConfig,
    PrefKeys.ongoingNotif,
    PrefKeys.dailyHadithNotif,
    PrefKeys.dailyAyahNotif, PrefKeys.fullScreenAdhan, PrefKeys.notifVibration,
    PrefKeys.notifLed, PrefKeys.prayerAlerts, PrefKeys.smartSilent,
    PrefKeys.kandilNotif, PrefKeys.cumaNotif, PrefKeys.ramadanMode,
    PrefKeys.checkinPrompt,
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

  /// Son senkron damgası. [at] verilirse SUNUCU updated_at'i (cihazlar arası
  /// karşılaştırma sunucu saatinde olsun diye); verilmezse yerel saat.
  Future<void> _stamp([int? at]) async {
    await ref
        .read(sharedPreferencesProvider)
        .setInt(
          PrefKeys.lastSyncAt,
          at ?? DateTime.now().millisecondsSinceEpoch,
        );
  }

  int get _lastStamp =>
      ref.read(sharedPreferencesProvider).getInt(PrefKeys.lastSyncAt) ?? 0;

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
        await _applyRemote(remote.data, localHatim);
        await _stamp(remote.updatedAt);
      } else {
        // Yeni/boş hesap → mevcut yerel (misafir) veriyi hesaba yükle (seed).
        final at = await AuthApi.putData(auth.token!, _collect(), _device());
        await _stamp(at);
      }
      _refresh();
      state = SyncState(syncing: false, lastSyncedAt: _lastStamp);
    } catch (e) {
      await _handleError(e);
      state = SyncState(
        syncing: false,
        lastSyncedAt: state.lastSyncedAt,
        error: _code(e),
      );
    }
  }

  /// Uygulamaya DÖNÜŞTE (resume): bulut son senkronumuzdan DAHA YENİYSE (başka
  /// cihaz yazmış) sessizce çek + uygula → çok-cihazda güncel kal. Yalnız bulut
  /// kesin daha yeniyken uygular (yerel değişikliği boş yere ezmemek için);
  /// arka plana alınınca zaten push edildiğinden yerel hep buluta yansımıştır.
  Future<void> syncOnResume() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.loggedIn || state.syncing) return;
    state = SyncState(syncing: true, lastSyncedAt: state.lastSyncedAt);
    final prefs = ref.read(sharedPreferencesProvider);
    final localHatim = prefs.getString(PrefKeys.hatimState);
    try {
      final remote = await AuthApi.getData(auth.token!);
      if (remote.data.isNotEmpty && remote.updatedAt > state.lastSyncedAt) {
        await _applyRemote(remote.data, localHatim);
        await _stamp(remote.updatedAt);
        _refresh();
      }
      state = SyncState(syncing: false, lastSyncedAt: _lastStamp);
    } catch (e) {
      await _handleError(e);
      state = SyncState(
        syncing: false,
        lastSyncedAt: state.lastSyncedAt,
        error: _code(e),
      );
    }
  }

  /// Buluttan gelen veriyi yerele uygular: yereli temizle + bulutu yaz + hatim'i
  /// gün-gün birleştir (overwrite değil). [localHatim] = temizlemeden önceki hatim.
  Future<void> _applyRemote(
    Map<String, dynamic> data,
    String? localHatim,
  ) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await _clearLocal();
    await _apply(data);
    final merged = mergeHatimData(
      HatimData.decode(localHatim),
      HatimData.decode(prefs.getString(PrefKeys.hatimState)),
    );
    await prefs.setString(PrefKeys.hatimState, merged.encode());
  }

  /// Sunucu oturumu reddettiyse (token süresi doldu VEYA hesap başka cihazda
  /// açıldığı için bu cihaz DÜŞÜRÜLDÜ — en fazla 2 cihaz) yerel oturumu kapat.
  Future<void> _handleError(Object e) async {
    if (_code(e) == 'unauthorized') {
      await ref.read(authControllerProvider.notifier).sessionRevoked();
    }
  }

  /// Yerel değişiklikleri buluta gönder (lifecycle pause — sessiz).
  Future<void> push() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.loggedIn || state.syncing) return;
    try {
      final at = await AuthApi.putData(auth.token!, _collect(), _device());
      await _stamp(at);
      state = SyncState(syncing: false, lastSyncedAt: at);
    } catch (e) {
      await _handleError(
        e,
      ); // 401 → oturum kapat; diğer hatalar sessiz (tekrar denenir)
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
