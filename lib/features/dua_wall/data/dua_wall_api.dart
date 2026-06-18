import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/cdn.dart';

/// Sunucu hata kodunu taşır; UI bunu kullanıcı mesajına eşler.
class DuaWallException implements Exception {
  final String code;
  DuaWallException(this.code);
  @override
  String toString() => 'DuaWallException($code)';
}

/// Dua Duvarı gönderisi (onaylı duvar öğesi veya kullanıcının kendi gönderisi).
class DuaPost {
  final String id;
  final String rumuz;
  final String text;
  final int amins;
  final int createdAt;
  final String status; // yalnız /mine için: pending|approved|rejected
  const DuaPost({
    required this.id,
    required this.rumuz,
    required this.text,
    required this.amins,
    required this.createdAt,
    this.status = 'approved',
  });
  factory DuaPost.fromJson(Map<String, dynamic> j) => DuaPost(
        id: (j['id'] ?? '').toString(),
        rumuz: (j['rumuz'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        amins: (j['amins'] as num?)?.toInt() ?? 0,
        createdAt: (j['created_at'] as num?)?.toInt() ?? 0,
        status: (j['status'] ?? 'approved').toString(),
      );
}

/// api.selaya.app — Dua Duvarı uçlarının istemcisi.
class DuaWallApi {
  static const _timeout = Duration(seconds: 15);
  static Uri _u(String p) => Uri.parse('${SelayaCdn.apiBase}$p');

  /// Onaylı duaları getir (herkese açık). [before] = sayfalama imleci (ms).
  static Future<List<DuaPost>> list({int? before}) async {
    final q = before != null ? '?before=$before' : '';
    http.Response res;
    try {
      res = await http.get(_u('/v1/dua-wall$q')).timeout(_timeout);
    } catch (_) {
      throw DuaWallException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      return ((d['duas'] as List?) ?? const [])
          .map((e) => DuaPost.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }
    throw DuaWallException((d['error'] ?? 'unknown').toString());
  }

  /// Kullanıcının kendi gönderileri (durumlarıyla).
  static Future<List<DuaPost>> mine(String token) async {
    http.Response res;
    try {
      res = await http
          .get(_u('/v1/dua-wall/mine'),
              headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
    } catch (_) {
      throw DuaWallException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      return ((d['duas'] as List?) ?? const [])
          .map((e) => DuaPost.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }
    throw DuaWallException((d['error'] ?? 'unknown').toString());
  }

  /// Dua gönder (onaya düşer). Hata kodunu DuaWallException olarak fırlatır.
  static Future<void> submit(String token, String text) async {
    http.Response res;
    try {
      res = await http
          .post(_u('/v1/dua-wall'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'text': text}))
          .timeout(_timeout);
    } catch (_) {
      throw DuaWallException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) return;
    throw DuaWallException((d['error'] ?? 'unknown').toString());
  }

  /// Bir duaya "Âmin" de (kullanıcı başına 1). Güncel sayıyı döner.
  static Future<int> amin(String token, String id) async {
    http.Response res;
    try {
      res = await http
          .post(_u('/v1/dua-wall/amin'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'id': id}))
          .timeout(_timeout);
    } catch (_) {
      throw DuaWallException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      return (d['amins'] as num?)?.toInt() ?? 0;
    }
    throw DuaWallException((d['error'] ?? 'unknown').toString());
  }

  /// Rumuz (takma ad) belirle/güncelle. Geçerli rumuzu döner.
  static Future<String> setRumuz(String token, String rumuz) async {
    http.Response res;
    try {
      res = await http
          .post(_u('/v1/dua-wall/rumuz'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'rumuz': rumuz}))
          .timeout(_timeout);
    } catch (_) {
      throw DuaWallException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      return (d['rumuz'] ?? '').toString();
    }
    throw DuaWallException((d['error'] ?? 'unknown').toString());
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      return (jsonDecode(res.body) as Map).cast<String, dynamic>();
    } catch (_) {
      return {'ok': false, 'error': 'bad_response'};
    }
  }
}
