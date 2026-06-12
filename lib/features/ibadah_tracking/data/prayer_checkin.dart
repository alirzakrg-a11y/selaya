import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../settings/presentation/settings_controller.dart';

/// "Did you pray this prayer?" check-in (#4).
///
/// A while after a fard prayer's time passes, the next time the user opens the
/// app we ask whether it was prayed. "Yes" logs it into İbadet Takibi (the same
/// SharedPreferences store the tracking screen uses) with a kind confirmation;
/// either answer is remembered so we don't re-ask the same prayer that day.

/// The tracking screen stores the dawn prayer as 'fajr'; Sunrise isn't a salah
/// so it's excluded.
const _trackName = <PrayerSlot, String>{
  PrayerSlot.imsak: 'fajr',
  PrayerSlot.dhuhr: 'dhuhr',
  PrayerSlot.asr: 'asr',
  PrayerSlot.maghrib: 'maghrib',
  PrayerSlot.isha: 'isha',
};

String _dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

/// The most recent fard prayer that passed (≥ [graceMin] min ago) today and
/// hasn't yet been logged or asked about — or null when there's nothing to ask.
Future<PrayerSlot?> pendingPrayerCheckIn(WidgetRef ref,
    {int graceMin = 20}) async {
  final prefs = ref.read(sharedPreferencesProvider);
  // Ayarlardan kapatılabilir: "namazı kıldın mı?" sorusu istemeyen sormasın.
  if (!(prefs.getBool(PrefKeys.checkinPrompt) ?? true)) return null;
  final City city;
  try {
    city = await ref.read(selectedCityProvider.future);
  } catch (_) {
    return null;
  }
  final settings = ref.read(settingsProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final times = computeTimes(city, settings, today);
  final key = _dayKey(today);
  final marked =
      (prefs.getStringList('${PrefKeys.trackingPrefix}$key') ?? const [])
          .toSet();
  final asked =
      (prefs.getStringList('${PrefKeys.trackingAskedPrefix}$key') ?? const [])
          .toSet();
  // Most-recent first, so we ask about the latest unanswered prayer.
  const order = [
    PrayerSlot.isha,
    PrayerSlot.maghrib,
    PrayerSlot.asr,
    PrayerSlot.dhuhr,
    PrayerSlot.imsak,
  ];
  for (final slot in order) {
    final name = _trackName[slot]!;
    if (marked.contains(name) || asked.contains(name)) continue;
    if (now.difference(times.timeOf(slot)).inMinutes >= graceMin) return slot;
  }
  return null;
}

Future<void> _record(WidgetRef ref, PrayerSlot slot,
    {required bool prayed}) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final key = _dayKey(DateTime.now());
  final name = _trackName[slot]!;
  // Remember we asked (either answer) so we don't prompt again today.
  final asked =
      (prefs.getStringList('${PrefKeys.trackingAskedPrefix}$key') ?? const [])
          .toSet()
        ..add(name);
  await prefs.setStringList(
      '${PrefKeys.trackingAskedPrefix}$key', asked.toList());
  if (prayed) {
    final marked =
        (prefs.getStringList('${PrefKeys.trackingPrefix}$key') ?? const [])
            .toSet()
          ..add(name);
    await prefs.setStringList(
        '${PrefKeys.trackingPrefix}$key', marked.toList());
  }
}

/// Shows the "kıldın mı?" dialog for [slot]. Yes → logs to İbadet Takibi + a
/// kind confirmation; No → just remembered. Dismissing leaves it for next time.
Future<void> showPrayerCheckIn(
    BuildContext context, WidgetRef ref, PrayerSlot slot) async {
  final c = context.colors;
  final name = 'prayer.${_trackName[slot]}'.tr();
  final prayed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      title: Text('tracking.checkInTitle'.tr()),
      content: Text('tracking.checkInQuestion'.tr(args: [name])),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.no'.tr())),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.yes'.tr())),
      ],
    ),
  );
  if (prayed == null) return;
  await _record(ref, slot, prayed: prayed);
  if (prayed && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('tracking.checkInAccepted'.tr()),
      backgroundColor: c.gold,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
