import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/auth_user.dart';
import 'auth_api.dart';

/// Oturum durumu. Misafir = user/token null.
class AuthState {
  final AuthUser? user;
  final String? token;
  const AuthState({this.user, this.token});

  bool get loggedIn => user != null && (token?.isNotEmpty ?? false);
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final token = prefs.getString(PrefKeys.authToken);
    final raw = prefs.getString(PrefKeys.authUser);
    if (token != null && token.isNotEmpty && raw != null) {
      try {
        return AuthState(
          token: token,
          user: AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {}
    }
    return const AuthState();
  }

  Future<void> login({required String email, required String password}) async {
    await _persist(
      await AuthApi.login(
        email: email,
        password: password,
        deviceId: _ensureDeviceId(),
        deviceLabel: defaultTargetPlatform.name,
      ),
    );
  }

  /// Google ile giriş — [idToken] google_sign_in'den gelir. YENİ kullanıcı +
  /// rumuz yoksa AuthApi `rumuz_required` fırlatır → çağıran (auth_screen)
  /// tek-seferlik rumuz alıp aynı idToken + rumuz ile tekrar çağırır.
  Future<void> googleLogin({required String idToken, String? rumuz}) async {
    await _persist(
      await AuthApi.google(
        idToken: idToken,
        rumuz: rumuz,
        deviceId: _ensureDeviceId(),
        deviceLabel: defaultTargetPlatform.name,
      ),
    );
  }

  Future<void> register({
    required String name,
    required String surname,
    required String email,
    required String password,
    required String rumuz,
  }) async {
    await _persist(
      await AuthApi.register(
        name: name,
        surname: surname,
        email: email,
        password: password,
        rumuz: rumuz,
        deviceId: _ensureDeviceId(),
        deviceLabel: defaultTargetPlatform.name,
      ),
    );
  }

  /// Sunucu hesabı BANLADI (403 banned). Yerel oturumu kapat + "engellendiniz"
  /// bilgisini işaretle (app.dart bir kez gösterir). Banlı kullanıcı giremez.
  Future<void> banned() async {
    await ref.read(sharedPreferencesProvider).setBool(PrefKeys.bannedFlag, true);
    await logout();
  }

  /// Bu kuruluma özel KALICI cihaz kimliği (en fazla 2 cihaz limiti için). İlk
  /// ihtiyaçta üretilir + prefs'e yazılır; SENKRONLANMAZ (her cihaz benzersiz).
  String _ensureDeviceId() {
    final prefs = ref.read(sharedPreferencesProvider);
    var id = prefs.getString(PrefKeys.deviceId);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List<int>.generate(
        16,
        (_) => r.nextInt(256),
      ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      prefs.setString(PrefKeys.deviceId, id);
    }
    return id;
  }

  /// Sunucu oturumu reddetti (token süresi doldu VEYA hesap başka cihazda açıldı
  /// — en fazla 2 cihaz, bu cihaz düşürüldü). Yerel oturumu kapat + sebebi
  /// işaretle (UI bir kez bilgilendirsin).
  Future<void> sessionRevoked() async {
    if (!state.loggedIn) return;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.sessionRevoked, true);
    await logout();
  }

  Future<void> _persist(AuthResult r) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(PrefKeys.authToken, r.token);
    await prefs.setString(PrefKeys.authUser, jsonEncode(r.user.toJson()));
    state = AuthState(token: r.token, user: r.user);
  }

  /// Profil (ad/soyad) güncellendi → yerel kaydı tazele.
  Future<void> updateUser(AuthUser user) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.authUser, jsonEncode(user.toJson()));
    state = AuthState(token: state.token, user: user);
  }

  Future<void> logout() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(PrefKeys.authToken);
    await prefs.remove(PrefKeys.authUser);
    state = const AuthState();
  }

  /// Hesabı kalıcı sil (şifre teyitli) → sunucudaki tüm veri silinir, ardından
  /// yerel oturum kapatılır. Hata olursa [AuthException] fırlatır.
  Future<void> deleteAccount(String password) async {
    final token = state.token;
    if (token == null) return;
    await AuthApi.deleteAccount(token, password);
    await logout();
  }

  /// Sunucunun verdiği taze token'ı uygula. Şifre değişiminde sunucu eski tüm
  /// oturumları (diğer cihazlar) düşürür ama bu cihaza yeni token verir →
  /// kullanıcı çıkış yapmadan devam eder.
  Future<void> applyToken(String token) async {
    if (token.isEmpty) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(PrefKeys.authToken, token);
    state = AuthState(user: state.user, token: token);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
