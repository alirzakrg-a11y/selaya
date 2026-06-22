import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/cdn.dart';
import '../../auth/data/auth_controller.dart';

class HatimException implements Exception {
  final String code;
  HatimException(this.code);
  @override
  String toString() => 'HatimException($code)';
}

/// Bir kampanyadaki tek cüz (open | claimed | done).
class HatimJuz {
  final int juzNo;
  final String status;
  final String? rumuz;
  final bool mine;
  const HatimJuz(this.juzNo, this.status, this.rumuz, this.mine);
  factory HatimJuz.fromJson(Map<String, dynamic> j) => HatimJuz(
        (j['juz_no'] as num?)?.toInt() ?? 0,
        (j['status'] ?? 'open').toString(),
        j['rumuz']?.toString(),
        j['mine'] == true,
      );
}

/// Bir hatim kampanyası (varsayılan topluluk hatmi ya da niyetli).
class HatimCampaign {
  final String id;
  final String title;
  final String? intention;
  final String? createdRumuz;
  final int createdAt;
  final int done;
  final int total;
  final String status;
  final List<HatimJuz> juz;
  const HatimCampaign({
    required this.id,
    required this.title,
    required this.intention,
    required this.createdRumuz,
    required this.createdAt,
    required this.done,
    required this.total,
    required this.status,
    required this.juz,
  });
  factory HatimCampaign.fromJson(Map<String, dynamic> j) => HatimCampaign(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        intention: j['intention']?.toString(),
        createdRumuz: j['created_rumuz']?.toString(),
        createdAt: (j['created_at'] as num?)?.toInt() ?? 0,
        done: (j['done'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 30,
        status: (j['status'] ?? 'active').toString(),
        juz: ((j['juz'] as List?) ?? const [])
            .map((e) => HatimJuz.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class HatimData {
  final List<HatimCampaign> campaigns;
  final List<Map<String, dynamic>> completed;
  const HatimData(this.campaigns, this.completed);
}

/// api.selaya.app — Topluluk Hatmi uçlarının istemcisi.
class HatimApi {
  static const _timeout = Duration(seconds: 15);
  static Uri _u(String p) => Uri.parse('${SelayaCdn.apiBase}$p');

  /// Aktif kampanyalar + son tamamlananlar. Token verilirse cüzler "mine" işaretlenir.
  static Future<HatimData> list({String? token}) async {
    http.Response res;
    try {
      res = await http
          .get(_u('/v1/hatim'),
              headers:
                  token != null ? {'Authorization': 'Bearer $token'} : null)
          .timeout(_timeout);
    } catch (_) {
      throw HatimException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      final campaigns = ((d['campaigns'] as List?) ?? const [])
          .map((e) => HatimCampaign.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      final completed = ((d['completed'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      return HatimData(campaigns, completed);
    }
    throw HatimException((d['error'] ?? 'unknown').toString());
  }

  static Future<HatimCampaign> _post(
      String token, String path, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await http
          .post(_u(path),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(body))
          .timeout(_timeout);
    } catch (_) {
      throw HatimException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      return HatimCampaign.fromJson(
          (d['campaign'] as Map).cast<String, dynamic>());
    }
    throw HatimException((d['error'] ?? 'unknown').toString());
  }

  static Future<HatimCampaign> claim(String token, String campaign, int juz) =>
      _post(token, '/v1/hatim/claim', {'campaign': campaign, 'juz': juz});
  static Future<HatimCampaign> release(String token, String campaign, int juz) =>
      _post(token, '/v1/hatim/release', {'campaign': campaign, 'juz': juz});
  static Future<HatimCampaign> markDone(String token, String campaign, int juz) =>
      _post(token, '/v1/hatim/done', {'campaign': campaign, 'juz': juz});
  static Future<HatimCampaign> create(
          String token, String title, String intention) =>
      _post(token, '/v1/hatim/create', {'title': title, 'intention': intention});

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      return (jsonDecode(res.body) as Map).cast<String, dynamic>();
    } catch (_) {
      return {'ok': false, 'error': 'bad_response'};
    }
  }
}

/// Aktif kampanyalar + son tamamlananlar (giriş varsa "mine" işaretli).
final communityHatimProvider = FutureProvider.autoDispose<HatimData>((ref) {
  final token = ref.watch(authControllerProvider).token;
  return HatimApi.list(token: token);
});
