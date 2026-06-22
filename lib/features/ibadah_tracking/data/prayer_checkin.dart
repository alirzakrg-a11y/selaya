import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../settings/presentation/settings_controller.dart';

/// "Did you pray?" check-in (#4) — batch edition.
///
/// When the user opens the app, every fard prayer whose time has already passed
/// today (and hasn't been logged or answered yet) is collected. A single popup
/// lists them all with checkboxes so the user can tick the ones they prayed —
/// e.g. opening at night after Sabah/Öğle/İkindi/Akşam all passed — and save
/// them to İbadet Takibi in one go. Whatever is shown is remembered as "asked",
/// so we don't nag about the same prayer again that day.

/// The tracking screen stores the dawn prayer as 'fajr'; Sunrise isn't a salah
/// so it's excluded.
const _trackName = <PrayerSlot, String>{
  PrayerSlot.imsak: 'fajr',
  PrayerSlot.dhuhr: 'dhuhr',
  PrayerSlot.asr: 'asr',
  PrayerSlot.maghrib: 'maghrib',
  PrayerSlot.isha: 'isha',
};

/// Chronological order (Sabah → Yatsı) so the popup reads top-to-bottom by time.
const _order = [
  PrayerSlot.imsak,
  PrayerSlot.dhuhr,
  PrayerSlot.asr,
  PrayerSlot.maghrib,
  PrayerSlot.isha,
];

String _dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

typedef PendingPrayer = ({PrayerSlot slot, DateTime time});

/// Every fard prayer that passed (≥ [graceMin] min ago) today and hasn't yet
/// been logged or asked about — chronological. Empty when there's nothing to
/// ask (or the user turned the prompt off in Settings).
Future<List<PendingPrayer>> pendingPrayerCheckIns(WidgetRef ref,
    {int graceMin = 20}) async {
  final prefs = ref.read(sharedPreferencesProvider);
  // Ayarlardan kapatılabilir: "namazı kıldın mı?" sorusu istemeyen sormasın.
  if (!(prefs.getBool(PrefKeys.checkinPrompt) ?? true)) return const [];
  final City city;
  try {
    city = await ref.read(selectedCityProvider.future);
  } catch (_) {
    return const [];
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
  final out = <PendingPrayer>[];
  for (final slot in _order) {
    final name = _trackName[slot]!;
    if (marked.contains(name) || asked.contains(name)) continue;
    final t = times.timeOf(slot);
    if (now.difference(t).inMinutes >= graceMin) out.add((slot: slot, time: t));
  }
  return out;
}

/// Marks every [shown] prayer as "asked" (so we don't re-prompt today) and the
/// [prayed] subset as completed in İbadet Takibi. [day] is the date the popup
/// was built for — used directly (not DateTime.now()) so a popup left open
/// across midnight still writes to the correct day's tracking keys.
Future<void> _recordBatch(WidgetRef ref,
    {required Set<PrayerSlot> prayed,
    required List<PrayerSlot> shown,
    required DateTime day}) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final key = _dayKey(day);
  final asked =
      (prefs.getStringList('${PrefKeys.trackingAskedPrefix}$key') ?? const [])
          .toSet();
  final marked =
      (prefs.getStringList('${PrefKeys.trackingPrefix}$key') ?? const [])
          .toSet();
  for (final slot in shown) {
    asked.add(_trackName[slot]!);
  }
  for (final slot in prayed) {
    marked.add(_trackName[slot]!);
  }
  await prefs.setStringList(
      '${PrefKeys.trackingAskedPrefix}$key', asked.toList());
  await prefs.setStringList('${PrefKeys.trackingPrefix}$key', marked.toList());
}

String _fmt(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Batch check-in popup: tick the prayers you've completed today, then save.
/// "Kaydet" logs ticked prayers to İbadet Takibi and remembers all listed ones
/// as asked. "Sonra" leaves everything for the next app open.
Future<void> showPrayerCheckInBatch(
    BuildContext context, WidgetRef ref, List<PendingPrayer> pending) async {
  if (pending.isEmpty) return;
  final c = context.colors;
  final checked = <PrayerSlot>{}; // boş başlar — kullanıcı kıldıklarını işaretler

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        final allOn = checked.length == pending.length;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Row(children: [
            Icon(Icons.mosque_rounded, color: c.gold, size: 22),
            const Gap.sm(),
            Expanded(child: Text('tracking.checkInTitle'.tr())),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('tracking.checkInBatchSubtitle'.tr(),
                    style: TextStyle(color: c.textSecondary, fontSize: 13)),
                const Gap.sm(),
                for (final p in pending)
                  CheckboxListTile(
                    value: checked.contains(p.slot),
                    onChanged: (v) => setSt(() => v == true
                        ? checked.add(p.slot)
                        : checked.remove(p.slot)),
                    activeColor: c.gold,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    title: Text('prayer.${_trackName[p.slot]}'.tr()),
                    secondary: Text(_fmt(p.time),
                        style: TextStyle(
                            color: c.textTertiary,
                            fontWeight: FontWeight.w600)),
                  ),
                if (pending.length > 1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setSt(() {
                        if (allOn) {
                          checked.clear();
                        } else {
                          checked.addAll(pending.map((e) => e.slot));
                        }
                      }),
                      icon: Icon(
                          allOn
                              ? Icons.remove_done_rounded
                              : Icons.done_all_rounded,
                          size: 18,
                          color: c.gold),
                      label: Text(
                          allOn
                              ? 'tracking.checkInClearAll'.tr()
                              : 'tracking.checkInAll'.tr(),
                          style: TextStyle(color: c.gold)),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('common.later'.tr())),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('common.save'.tr())),
          ],
        );
      },
    ),
  );
  if (saved != true) return;
  // Use the day the popup was built for (pending times are on that day) so a
  // save that lands after midnight still writes to the correct day's keys.
  await _recordBatch(ref,
      prayed: checked,
      shown: pending.map((e) => e.slot).toList(),
      day: pending.first.time);
  if (!context.mounted) return;
  final n = checked.length;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(n > 0
        ? 'tracking.checkInSavedN'.tr(args: ['$n'])
        : 'tracking.checkInNoneSaved'.tr()),
    backgroundColor: c.gold,
    behavior: SnackBarBehavior.floating,
  ));
}
