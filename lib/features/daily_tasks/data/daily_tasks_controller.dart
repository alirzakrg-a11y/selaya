import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/daily_task.dart';

/// Persisted daily-task completion log (#18): `{ 'yyyy-MM-dd': [taskId, …] }`.
/// Survives restarts (SharedPreferences) and is pruned to the last ~10 weeks so
/// it can't grow unbounded. All reads/writes go through this controller.
class DailyTasksController extends Notifier<Map<String, List<String>>> {
  static const _keepDays = 70;

  @override
  Map<String, List<String>> build() =>
      _decode(ref.read(sharedPreferencesProvider).getString(PrefKeys.dailyTasksLog));

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  List<String> doneOn(DateTime d) => state[dateKey(d)] ?? const [];

  bool isDoneToday(String taskId) => doneOn(DateTime.now()).contains(taskId);

  /// Toggle a task's completion for *today* and persist.
  Future<void> toggleToday(String taskId) async {
    final key = dateKey(DateTime.now());
    final today = List<String>.from(state[key] ?? const []);
    if (today.contains(taskId)) {
      today.remove(taskId);
    } else {
      today.add(taskId);
    }
    final next = Map<String, List<String>>.from(state)..[key] = today;
    _prune(next);
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.dailyTasksLog, jsonEncode(next));
    state = next;
  }

  static void _prune(Map<String, List<String>> m) {
    if (m.length <= _keepDays) return;
    final keys = m.keys.toList()..sort();
    for (final k in keys.take(m.length - _keepDays)) {
      m.remove(k);
    }
  }

  static Map<String, List<String>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          e.key: (e.value as List).map((v) => v.toString()).toList(),
      };
    } catch (_) {
      return {};
    }
  }
}

final dailyTasksProvider =
    NotifierProvider<DailyTasksController, Map<String, List<String>>>(
        DailyTasksController.new);

/// Derived, read-only stats over the completion log (today + history).
@immutable
class TaskStats {
  final int todayDone; // 0..dailyTaskCount
  final int streak; // consecutive days (ending today/yesterday) with ≥1 done
  final int totalDone; // all-time completed count
  final int perfectDays; // days that hit the full daily target
  final List<int> last7; // completed-count per day, oldest → newest (length 7)

  const TaskStats({
    required this.todayDone,
    required this.streak,
    required this.totalDone,
    required this.perfectDays,
    required this.last7,
  });
}

/// Pure stats computation from the log (target = tasks shown per day).
TaskStats computeTaskStats(Map<String, List<String>> log, {int target = 5}) {
  final now = DateTime.now();
  String key(DateTime d) => DailyTasksController.dateKey(d);
  int countOn(DateTime d) => (log[key(d)]?.length ?? 0);

  final todayDone = countOn(now).clamp(0, target);
  final last7 = <int>[
    for (var i = 6; i >= 0; i--)
      countOn(now.subtract(Duration(days: i))).clamp(0, target),
  ];

  var totalDone = 0;
  var perfectDays = 0;
  for (final v in log.values) {
    totalDone += v.length;
    if (v.length >= target) perfectDays++;
  }

  // Streak: walk back from today (or yesterday if today is empty so far) while
  // each day has at least one completed task.
  var streak = 0;
  var cursor = now;
  if (countOn(now) == 0) cursor = now.subtract(const Duration(days: 1));
  while (countOn(cursor) >= 1) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return TaskStats(
    todayDone: todayDone,
    streak: streak,
    totalDone: totalDone,
    perfectDays: perfectDays,
    last7: last7,
  );
}

final taskStatsProvider = Provider<TaskStats>((ref) {
  final log = ref.watch(dailyTasksProvider);
  // ⑤ Hedef = günde gösterilen görev sayısı (dailyTaskCount=8), eskiden 5'e
  // clamp'leniyordu → "5/8" donuyordu.
  return computeTaskStats(log, target: dailyTaskCount);
});

/// An achievement badge (#18 "rozet sistemi"). Bilingual inline; [earned] is a
/// pure predicate over [TaskStats].
@immutable
class TaskBadge {
  final String id;
  final String titleTr;
  final String titleEn;
  final IconData icon;
  final bool Function(TaskStats) earned;
  const TaskBadge(this.id, this.titleTr, this.titleEn, this.icon, this.earned);
  String title(String lang) => lang == 'tr' ? titleTr : titleEn;
}

const List<TaskBadge> taskBadges = [
  TaskBadge('first', 'İlk Adım', 'First Step', Icons.flag_rounded, _first),
  TaskBadge('perfect', 'Tam Gün', 'Perfect Day', Icons.verified_rounded,
      _perfect),
  TaskBadge('streak3', '3 Gün Seri', '3-Day Streak',
      Icons.local_fire_department_rounded, _streak3),
  TaskBadge('streak7', '7 Gün Seri', '7-Day Streak', Icons.whatshot_rounded,
      _streak7),
  TaskBadge('total50', '50 Görev', '50 Tasks', Icons.military_tech_rounded,
      _total50),
  TaskBadge('total100', '100 Görev', '100 Tasks',
      Icons.workspace_premium_rounded, _total100),
  TaskBadge('streak14', '14 Gün Seri', '14-Day Streak',
      Icons.bolt_rounded, _streak14),
  TaskBadge('streak30', '30 Gün Seri', '30-Day Streak',
      Icons.electric_bolt_rounded, _streak30),
  TaskBadge('perfect7', '7 Tam Gün', '7 Perfect Days',
      Icons.star_rounded, _perfect7),
  TaskBadge('perfect30', '30 Tam Gün', '30 Perfect Days',
      Icons.auto_awesome_rounded, _perfect30),
  TaskBadge('total250', '250 Görev', '250 Tasks',
      Icons.emoji_events_rounded, _total250),
  TaskBadge('total500', '500 Görev', '500 Tasks',
      Icons.diamond_rounded, _total500),
  TaskBadge('total25', '25 Görev', '25 Tasks', Icons.task_alt_rounded, _total25),
  TaskBadge('streak60', '60 Gün Seri', '60-Day Streak',
      Icons.whatshot_rounded, _streak60),
  TaskBadge('streak100', '100 Gün Seri', '100-Day Streak',
      Icons.local_fire_department_rounded, _streak100),
  TaskBadge('perfect15', '15 Tam Gün', '15 Perfect Days',
      Icons.brightness_5_rounded, _perfect15),
  TaskBadge('perfect100', '100 Tam Gün', '100 Perfect Days',
      Icons.brightness_7_rounded, _perfect100),
  TaskBadge('total1000', '1000 Görev', '1000 Tasks',
      Icons.shield_rounded, _total1000),
];

bool _first(TaskStats s) => s.totalDone >= 1;
bool _perfect(TaskStats s) => s.perfectDays >= 1;
bool _streak3(TaskStats s) => s.streak >= 3;
bool _streak7(TaskStats s) => s.streak >= 7;
bool _total50(TaskStats s) => s.totalDone >= 50;
bool _total100(TaskStats s) => s.totalDone >= 100;
bool _streak14(TaskStats s) => s.streak >= 14;
bool _streak30(TaskStats s) => s.streak >= 30;
bool _perfect7(TaskStats s) => s.perfectDays >= 7;
bool _perfect30(TaskStats s) => s.perfectDays >= 30;
bool _total250(TaskStats s) => s.totalDone >= 250;
bool _total500(TaskStats s) => s.totalDone >= 500;
bool _total25(TaskStats s) => s.totalDone >= 25;
bool _streak60(TaskStats s) => s.streak >= 60;
bool _streak100(TaskStats s) => s.streak >= 100;
bool _perfect15(TaskStats s) => s.perfectDays >= 15;
bool _perfect100(TaskStats s) => s.perfectDays >= 100;
bool _total1000(TaskStats s) => s.totalDone >= 1000;
