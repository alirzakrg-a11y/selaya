import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/asset_json_loader.dart';
import '../../../core/di/providers.dart';

/// ISO-8601 hafta anahtarı (YYYY-Www) — backend (quiz.js) ile birebir aynı.
String quizWeekKey([DateTime? at]) {
  final now = (at ?? DateTime.now()).toUtc();
  final date = DateTime.utc(now.year, now.month, now.day);
  final thursday = date.add(Duration(days: 4 - date.weekday)); // Mon=1..Sun=7
  final yearStart = DateTime.utc(thursday.year, 1, 1);
  final weekNo = ((thursday.difference(yearStart).inDays + 1) / 7).ceil();
  return '${thursday.year}-W${weekNo.toString().padLeft(2, '0')}';
}

int weekSeed(String week) {
  var h = 0;
  for (final c in week.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// Deterministik haftalık set: aynı hafta herkese aynı [count] soru, hafta
/// değişince yenilenir (week tohumuyla karıştırılır).
List<QuizQuestion> weeklyQuestions(
    List<QuizQuestion> pool, String week, int count) {
  final list = List<QuizQuestion>.from(pool)..shuffle(Random(weekSeed(week)));
  return list.take(count).toList();
}

/// One quiz question (bundled, verified Islamic knowledge).
class QuizQuestion {
  final String category;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  const QuizQuestion({
    required this.category,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        category: (j['cat'] ?? 'genel').toString(),
        question: (j['q'] ?? '').toString(),
        options:
            ((j['o'] as List?) ?? const []).map((e) => e.toString()).toList(),
        correctIndex: (j['c'] as num?)?.toInt() ?? 0,
        explanation: (j['e'] ?? '').toString(),
      );
}

final quizQuestionsProvider = FutureProvider<List<QuizQuestion>>(
  (ref) => ref.watch(assetJsonLoaderProvider).loadModels(
        'assets/data/quiz.json',
        QuizQuestion.fromJson,
      ),
);

/// Persisted quiz progress.
class QuizStats {
  final int points;
  final int streak; // consecutive days played
  final int best; // best correct-count in a single round
  final int totalAnswered;
  final int totalCorrect;
  const QuizStats({
    this.points = 0,
    this.streak = 0,
    this.best = 0,
    this.totalAnswered = 0,
    this.totalCorrect = 0,
  });
}

class QuizStatsController extends Notifier<QuizStats> {
  static const _kPoints = 'quiz_points';
  static const _kStreak = 'quiz_streak';
  static const _kBest = 'quiz_best';
  static const _kAnswered = 'quiz_total_answered';
  static const _kCorrect = 'quiz_total_correct';
  static const _kLastDay = 'quiz_last_day';

  @override
  QuizStats build() {
    final p = ref.read(sharedPreferencesProvider);
    return QuizStats(
      points: p.getInt(_kPoints) ?? 0,
      streak: p.getInt(_kStreak) ?? 0,
      best: p.getInt(_kBest) ?? 0,
      totalAnswered: p.getInt(_kAnswered) ?? 0,
      totalCorrect: p.getInt(_kCorrect) ?? 0,
    );
  }

  static String _dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

  /// Record a finished round of [total] questions, [correct] right. Awards 10
  /// points per correct answer and updates the consecutive-day streak.
  Future<void> recordRound({required int correct, required int total}) async {
    final p = ref.read(sharedPreferencesProvider);
    final points = (p.getInt(_kPoints) ?? 0) + correct * 10;
    final best = p.getInt(_kBest) ?? 0;
    final newBest = correct > best ? correct : best;
    final answered = (p.getInt(_kAnswered) ?? 0) + total;
    final totalCorrect = (p.getInt(_kCorrect) ?? 0) + correct;

    final today = _dayKey(DateTime.now());
    final last = p.getString(_kLastDay);
    var streak = p.getInt(_kStreak) ?? 0;
    if (last != today) {
      final yesterday =
          _dayKey(DateTime.now().subtract(const Duration(days: 1)));
      streak = (last == yesterday) ? streak + 1 : 1;
      await p.setString(_kLastDay, today);
    } else if (streak == 0) {
      streak = 1;
    }

    await p.setInt(_kPoints, points);
    await p.setInt(_kBest, newBest);
    await p.setInt(_kAnswered, answered);
    await p.setInt(_kCorrect, totalCorrect);
    await p.setInt(_kStreak, streak);
    state = QuizStats(
      points: points,
      streak: streak,
      best: newBest,
      totalAnswered: answered,
      totalCorrect: totalCorrect,
    );
  }
}

final quizStatsProvider =
    NotifierProvider<QuizStatsController, QuizStats>(QuizStatsController.new);
