import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/cdn.dart';
import '../../auth/data/auth_controller.dart';

class QuizException implements Exception {
  final String code;
  QuizException(this.code);
  @override
  String toString() => 'QuizException($code)';
}

/// One row on the weekly leaderboard.
class LeaderEntry {
  final String rumuz;
  final int score;
  final int correct;
  final int total;
  const LeaderEntry(this.rumuz, this.score, this.correct, this.total);
  factory LeaderEntry.fromJson(Map<String, dynamic> j) => LeaderEntry(
        (j['rumuz'] ?? '—').toString(),
        (j['score'] as num?)?.toInt() ?? 0,
        (j['correct'] as num?)?.toInt() ?? 0,
        (j['total'] as num?)?.toInt() ?? 0,
      );
}

class Leaderboard {
  final String week;
  final List<LeaderEntry> top;
  final int? myRank;
  final int? myScore;
  const Leaderboard(this.week, this.top, this.myRank, this.myScore);
}

/// api.selaya.app — Bilgi Yarışması liderlik tablosu + skor gönderimi.
class QuizApi {
  static const _timeout = Duration(seconds: 15);
  static Uri _u(String p) => Uri.parse('${SelayaCdn.apiBase}$p');

  /// Bu haftanın liderlik tablosu (token verilirse "me" = kendi sıran/skorun).
  static Future<Leaderboard> leaderboard({String? token, String? week}) async {
    http.Response res;
    try {
      final q = week != null ? '?week=$week' : '';
      res = await http
          .get(_u('/v1/quiz/leaderboard$q'),
              headers:
                  token != null ? {'Authorization': 'Bearer $token'} : null)
          .timeout(_timeout);
    } catch (_) {
      throw QuizException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      final top = ((d['top'] as List?) ?? const [])
          .map((e) => LeaderEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      final me = d['me'] as Map?;
      return Leaderboard(
        (d['week'] ?? '').toString(),
        top,
        me != null ? (me['rank'] as num?)?.toInt() : null,
        me != null ? (me['score'] as num?)?.toInt() : null,
      );
    }
    throw QuizException((d['error'] ?? 'unknown').toString());
  }

  /// Haftalık skoru gönder (en iyi tutulur). Dönen: o haftaki en iyi skorun.
  static Future<int> submit(
      String token, int score, int correct, int total) async {
    http.Response res;
    try {
      res = await http
          .post(_u('/v1/quiz/submit'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(
                  {'score': score, 'correct': correct, 'total': total}))
          .timeout(_timeout);
    } catch (_) {
      throw QuizException('network');
    }
    final d = _decode(res);
    if (res.statusCode == 200 && d['ok'] == true) {
      return (d['best'] as num?)?.toInt() ?? score;
    }
    throw QuizException((d['error'] ?? 'unknown').toString());
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      return (jsonDecode(res.body) as Map).cast<String, dynamic>();
    } catch (_) {
      return {'ok': false, 'error': 'bad_response'};
    }
  }
}

/// Bu haftanın liderlik tablosu (giriş varsa kendi sıran dahil).
final quizLeaderboardProvider =
    FutureProvider.autoDispose<Leaderboard>((ref) {
  final token = ref.watch(authControllerProvider).token;
  return QuizApi.leaderboard(token: token);
});
