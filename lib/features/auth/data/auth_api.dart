import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/cdn.dart';
import '../domain/auth_user.dart';

/// Sunucu hata kodunu taşır; UI bunu `auth.err_<code>` çevirisine eşler.
class AuthException implements Exception {
  final String code;
  AuthException(this.code);
  @override
  String toString() => 'AuthException($code)';
}

class AuthResult {
  final String token;
  final AuthUser user;
  const AuthResult(this.token, this.user);
}

/// api.selaya.app üzerindeki üyelik & senkron uçlarının istemcisi.
class AuthApi {
  static const _timeout = Duration(seconds: 15);
  static Uri _u(String p) => Uri.parse('${SelayaCdn.apiBase}$p');

  static Future<AuthResult> register({
    required String name,
    required String surname,
    required String email,
    required String password,
    String? deviceId,
    String? deviceLabel,
  }) => _auth('/v1/auth/register', {
    'name': name,
    'surname': surname,
    'email': email,
    'password': password,
    'deviceId': ?deviceId,
    'device': ?deviceLabel,
  });

  static Future<AuthResult> login({
    required String email,
    required String password,
    String? deviceId,
    String? deviceLabel,
  }) => _auth('/v1/auth/login', {
    'email': email,
    'password': password,
    'deviceId': ?deviceId,
    'device': ?deviceLabel,
  });

  static Future<AuthResult> _auth(
    String path,
    Map<String, dynamic> body,
  ) async {
    http.Response res;
    try {
      res = await http
          .post(
            _u(path),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      return AuthResult(
        (d['token'] ?? '').toString(),
        AuthUser.fromJson(
          ((d['user'] as Map?) ?? const {}).cast<String, dynamic>(),
        ),
      );
    }
    throw AuthException((d['error'] ?? 'unknown').toString());
  }

  /// Buluttaki kullanıcı verisini çek (Faz 3 senkron).
  static Future<({Map<String, dynamic> data, int updatedAt})> getData(
    String token,
  ) async {
    http.Response res;
    try {
      res = await http
          .get(_u('/v1/me/data'), headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      return (
        data: ((d['data'] as Map?) ?? const {}).cast<String, dynamic>(),
        updatedAt: (d['updated_at'] as num?)?.toInt() ?? 0,
      );
    }
    throw AuthException((d['error'] ?? 'unknown').toString());
  }

  /// Veriyi buluta yaz (Faz 3 senkron); dönen updatedAt damgasını verir.
  static Future<int> putData(
    String token,
    Map<String, dynamic> data,
    String device,
  ) async {
    http.Response res;
    try {
      res = await http
          .put(
            _u('/v1/me/data'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'data': data, 'device': device}),
          )
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      return (d['updated_at'] as num?)?.toInt() ?? 0;
    }
    throw AuthException((d['error'] ?? 'unknown').toString());
  }

  /// Girişli kullanıcının şifresini değiştir (eski şifre doğrulanır).
  static Future<void> changePassword(
    String token,
    String oldPw,
    String newPw,
  ) async {
    http.Response res;
    try {
      res = await http
          .post(
            _u('/v1/me/password'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'oldPassword': oldPw, 'newPassword': newPw}),
          )
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) return;
    throw AuthException((d['error'] ?? 'unknown').toString());
  }

  /// Profil güncelle (ad/soyad) → güncel AuthUser döner.
  static Future<AuthUser> updateProfile(
    String token,
    String name,
    String surname,
  ) async {
    http.Response res;
    try {
      res = await http
          .put(
            _u('/v1/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'name': name, 'surname': surname}),
          )
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      return AuthUser.fromJson(
        ((d['user'] as Map?) ?? const {}).cast<String, dynamic>(),
      );
    }
    throw AuthException((d['error'] ?? 'unknown').toString());
  }

  /// Şifremi unuttum: e-postaya kod gönder (Resend kuruluysa).
  static Future<void> forgot(String email) async {
    http.Response res;
    try {
      res = await http
          .post(
            _u('/v1/auth/forgot'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) return;
    throw AuthException((d['error'] ?? 'unknown').toString());
  }

  /// Kodla yeni şifre belirle.
  static Future<void> reset(String email, String code, String newPw) async {
    http.Response res;
    try {
      res = await http
          .post(
            _u('/v1/auth/reset'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'code': code,
              'newPassword': newPw,
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      throw AuthException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) return;
    throw AuthException((d['error'] ?? 'unknown').toString());
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      return (jsonDecode(res.body) as Map).cast<String, dynamic>();
    } catch (_) {
      return {'ok': false, 'error': 'bad_response'};
    }
  }
}
