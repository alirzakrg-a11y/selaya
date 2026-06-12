import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/notification_service.dart';
import '../domain/hatim_session.dart';
import 'hatim_controller.dart';

/// Hatim hatırlatması açık/kapalı (varsayılan KAPALI).
class HatimReminderController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(PrefKeys.hatimReminder) ??
      false;

  Future<void> set(bool v) async {
    await ref.read(sharedPreferencesProvider).setBool(PrefKeys.hatimReminder, v);
    state = v;
  }
}

final hatimReminderProvider =
    NotifierProvider<HatimReminderController, bool>(HatimReminderController.new);

/// Hatırlatma saati "HH:mm" (varsayılan 21:00).
class HatimReminderTimeController extends Notifier<String> {
  @override
  String build() =>
      ref.read(sharedPreferencesProvider).getString(PrefKeys.hatimReminderHm) ??
      '21:00';

  Future<void> set(String hm) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.hatimReminderHm, hm);
    state = hm;
  }
}

final hatimReminderTimeProvider =
    NotifierProvider<HatimReminderTimeController, String>(
        HatimReminderTimeController.new);

(int, int) parseHm(String hm) {
  final p = hm.split(':');
  final h = int.tryParse(p.first) ?? 21;
  final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
  return (h, m);
}

/// Hatim hatırlatmasını (yeniden) kur veya iptal et. Açılışta (splash) + ayar
/// değişiminde çağrılır. Aktif hatim yoksa / kapalıysa iptal eder; o gün hedef
/// tamamlandıysa ilk tetiği yarına atar.
Future<void> applyHatimReminder(WidgetRef ref, String lang) async {
  final notif = ref.read(notificationServiceProvider);
  final on = ref.read(hatimReminderProvider);
  final active = ref.read(hatimControllerProvider).active;
  if (!on || active == null || active.status != HatimStatus.active) {
    await notif.cancelHatimReminder();
    return;
  }
  if (!await notif.isGranted()) return;
  final (h, m) = parseHm(ref.read(hatimReminderTimeProvider));
  final metToday = active.readToday() >= active.dailyTarget;
  await notif.scheduleHatimReminder(
    hour: h,
    minute: m,
    title: lang == 'tr' ? 'Hatim Hatırlatması' : 'Khatm Reminder',
    body: lang == 'tr'
        ? 'Bugünkü hatim sayfaların seni bekliyor 📖'
        : 'Your pages for today are waiting 📖',
    skipToday: metToday,
  );
}
