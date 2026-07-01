import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/notification_service.dart';
import '../domain/special_prayers.dart';

/// Nafile namaz hatırlatıcıları: `key → "HH:mm"`. Her biri GÜNLÜK tekrarlayan
/// bildirim (namaz-vakti/ezan sisteminden ayrı). prefs'te JSON olarak saklanır.
class NafileReminderController extends Notifier<Map<String, String>> {
  static const _key = 'nafile_reminders';

  @override
  Map<String, String> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      return (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return const {};
    }
  }

  /// Sabit bildirim id'si — nafile listesindeki sıraya göre 6000+.
  int _idFor(String key) {
    final i = specialPrayers.indexWhere((p) => p.key == key);
    return 6000 + (i < 0 ? (key.hashCode & 0x3ff) : i);
  }

  Future<void> _persist() => ref
      .read(sharedPreferencesProvider)
      .setString(_key, jsonEncode(state));

  TimeOfDay? timeFor(String key) {
    final v = state[key];
    if (v == null) return null;
    final p = v.split(':');
    return TimeOfDay(
      hour: int.tryParse(p.first) ?? 0,
      minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
    );
  }

  Future<void> setReminder(SpecialPrayer prayer, TimeOfDay time) async {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    state = {...state, prayer.key: '$hh:$mm'};
    await _persist();
    await ref.read(notificationServiceProvider).scheduleNafileReminder(
          _idFor(prayer.key),
          prayer.nameTr,
          '$hh:$mm — nafile namaz hatırlatması',
          time.hour,
          time.minute,
        );
  }

  Future<void> clearReminder(String key) async {
    state = {...state}..remove(key);
    await _persist();
    await ref.read(notificationServiceProvider).cancelNafileReminder(_idFor(key));
  }
}

final nafileReminderProvider =
    NotifierProvider<NafileReminderController, Map<String, String>>(
        NafileReminderController.new);
