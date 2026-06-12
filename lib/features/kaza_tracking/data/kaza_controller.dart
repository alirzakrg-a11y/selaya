import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';

/// The five obligatory prayers plus Vitr, tracked as a running count of missed
/// (qada) prayers the user still owes. Persisted as a simple JSON map; the total
/// number of qada already prayed is kept separately for a motivation stat.
const kazaPrayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'vitr'];

class KazaCounts {
  final Map<String, int> counts;
  final int completed; // şu ana kadar kılınan toplam kaza (motivasyon)
  const KazaCounts(this.counts, {this.completed = 0});

  int countOf(String key) => counts[key] ?? 0;
  int get total => counts.values.fold(0, (a, b) => a + b);

  KazaCounts withCount(String key, int value) {
    final next = Map<String, int>.from(counts);
    next[key] = value < 0 ? 0 : value;
    return KazaCounts(next, completed: completed);
  }
}

class KazaController extends Notifier<KazaCounts> {
  @override
  KazaCounts build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(PrefKeys.kazaCounts);
    final done = prefs.getInt(PrefKeys.kazaCompleted) ?? 0;
    if (raw == null || raw.isEmpty) return KazaCounts(const {}, completed: done);
    try {
      final map = (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
      return KazaCounts(map, completed: done);
    } catch (_) {
      return KazaCounts(const {}, completed: done);
    }
  }

  Future<void> _persist(KazaCounts c) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(PrefKeys.kazaCounts, jsonEncode(c.counts));
    await prefs.setInt(PrefKeys.kazaCompleted, c.completed);
    state = c;
  }

  Future<void> setCount(String key, int value) =>
      _persist(state.withCount(key, value));

  Future<void> increment(String key, [int by = 1]) =>
      setCount(key, state.countOf(key) + by);

  /// Düzeltme amaçlı azaltma (kılınan sayacına eklemez).
  Future<void> decrement(String key, [int by = 1]) =>
      setCount(key, state.countOf(key) - by);

  /// "Kıldım": borç varsa bir azaltır ve kılınan toplamına ekler.
  Future<void> markPrayed(String key) async {
    final cur = state.countOf(key);
    if (cur <= 0) return;
    final next = state.withCount(key, cur - 1);
    await _persist(KazaCounts(next.counts, completed: state.completed + 1));
  }

  /// Toplu ekleme: her vakit için [days] gün kaza ekler.
  Future<void> addDays(int days) async {
    final next = Map<String, int>.from(state.counts);
    for (final k in kazaPrayers) {
      next[k] = (next[k] ?? 0) + days;
    }
    await _persist(KazaCounts(next, completed: state.completed));
  }
}

final kazaProvider =
    NotifierProvider<KazaController, KazaCounts>(KazaController.new);
