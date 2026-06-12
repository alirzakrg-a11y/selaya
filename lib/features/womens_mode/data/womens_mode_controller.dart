import 'dart:convert';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';

/// Women's mode: when enabled, days within a logged period (regl/nifas) are
/// *neutral* for prayer & fasting tracking — they neither break nor advance a
/// streak and can't be toggled. Labels are kept discreet.
class WomensMode {
  final bool enabled;
  final List<DateTimeRange> periods;
  const WomensMode({this.enabled = false, this.periods = const []});

  /// True if [day] falls inside any logged period (inclusive). Only when enabled.
  bool isExcluded(DateTime day) {
    if (!enabled) return false;
    final d = DateTime(day.year, day.month, day.day);
    for (final p in periods) {
      final s = DateTime(p.start.year, p.start.month, p.start.day);
      final e = DateTime(p.end.year, p.end.month, p.end.day);
      if (!d.isBefore(s) && !d.isAfter(e)) return true;
    }
    return false;
  }

  WomensMode copyWith({bool? enabled, List<DateTimeRange>? periods}) =>
      WomensMode(
          enabled: enabled ?? this.enabled, periods: periods ?? this.periods);
}

class WomensModeController extends Notifier<WomensMode> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  WomensMode build() => WomensMode(
        enabled: _prefs.getBool(PrefKeys.womensMode) ?? false,
        periods: _decode(_prefs.getString(PrefKeys.womensPeriods)),
      );

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(PrefKeys.womensMode, value);
    state = state.copyWith(enabled: value);
  }

  Future<void> addPeriod(DateTimeRange range) async {
    final next = [...state.periods, range]
      ..sort((a, b) => a.start.compareTo(b.start));
    await _persist(next);
  }

  Future<void> removePeriod(int index) async {
    if (index < 0 || index >= state.periods.length) return;
    final next = [...state.periods]..removeAt(index);
    await _persist(next);
  }

  Future<void> _persist(List<DateTimeRange> periods) async {
    await _prefs.setString(PrefKeys.womensPeriods, _encode(periods));
    state = state.copyWith(periods: periods);
  }

  static String _encode(List<DateTimeRange> p) => jsonEncode([
        for (final r in p)
          {'start': r.start.toIso8601String(), 'end': r.end.toIso8601String()}
      ]);

  static List<DateTimeRange> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          DateTimeRange(
            start: DateTime.parse((e as Map)['start'] as String),
            end: DateTime.parse(e['end'] as String),
          )
      ];
    } catch (_) {
      return const [];
    }
  }
}

final womensModeProvider =
    NotifierProvider<WomensModeController, WomensMode>(WomensModeController.new);
