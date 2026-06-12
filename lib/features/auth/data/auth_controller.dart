import 'dart:convert';

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
    await _persist(await AuthApi.login(email: email, password: password));
  }

  Future<void> register({
    required String name,
    required String surname,
    required String email,
    required String password,
  }) async {
    await _persist(await AuthApi.register(
        name: name, surname: surname, email: email, password: password));
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
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
