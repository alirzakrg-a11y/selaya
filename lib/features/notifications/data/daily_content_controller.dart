import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/services/notification_service.dart';

/// Persisted on/off switches for the two daily content notifications (verse +
/// hadith). Kept in SharedPreferences so the choice survives app restarts — the
/// bug being fixed was a non-persisted local toggle that reset on every launch.
/// Default ON: a daily verse + hadith is a core feature (still gated by the OS
/// notification permission, and fully user-toggleable in Settings).
class DailyHadithNotifController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(PrefKeys.dailyHadithNotif) ??
      true;

  Future<void> set(bool v) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.dailyHadithNotif, v);
    state = v;
  }
}

final dailyHadithNotifProvider =
    NotifierProvider<DailyHadithNotifController, bool>(
        DailyHadithNotifController.new);

class DailyAyahNotifController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(PrefKeys.dailyAyahNotif) ??
      true;

  Future<void> set(bool v) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.dailyAyahNotif, v);
    state = v;
  }
}

final dailyAyahNotifProvider =
    NotifierProvider<DailyAyahNotifController, bool>(
        DailyAyahNotifController.new);

/// (Re)schedules or cancels the daily hadith notification per [on]. Lives here
/// (not in the controller) because it needs the active [lang] for the localized
/// text. Called on app start (splash) and whenever the toggle changes (Settings).
Future<void> applyDailyHadith(WidgetRef ref, String lang, bool on) async {
  final notif = ref.read(notificationServiceProvider);
  if (!on) {
    await notif.cancelDailyHadith();
    return;
  }
  if (!await notif.isGranted()) return;
  final hadiths = await ref.read(hadithsProvider.future);
  if (hadiths.isEmpty) return;
  final h = hadiths[DateTime.now().day % hadiths.length];
  final label = lang == 'tr' ? 'Günün Hadisi' : 'Hadith of the Day';
  await notif.scheduleDailyHadith(
      title: label, text: h.text(lang), reference: h.collection);
}

/// (Re)schedules or cancels the daily verse-of-the-day notification per [on].
Future<void> applyDailyAyah(WidgetRef ref, String lang, bool on) async {
  final notif = ref.read(notificationServiceProvider);
  if (!on) {
    await notif.cancelDailyAyah();
    return;
  }
  if (!await notif.isGranted()) return;
  final items = await ref.read(inspirationProvider.future);
  if (items.isEmpty) return;
  final v = items[DateTime.now().day % items.length];
  final label = lang == 'tr' ? 'Günün Ayeti' : 'Verse of the Day';
  await notif.scheduleDailyAyah(
      title: label, text: v.text(lang), reference: v.reference);
}
