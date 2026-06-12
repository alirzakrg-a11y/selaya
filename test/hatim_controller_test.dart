import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selaya/core/di/providers.dart';
import 'package:selaya/features/hatim/data/hatim_controller.dart';
import 'package:selaya/features/hatim/domain/hatim_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
}

void main() {
  test('start: günlük hedef + currentPage = startPage-1', () async {
    final c = await _container();
    await c.read(hatimControllerProvider.notifier).start(
          startPage: 1,
          dailyTarget: 20,
        );
    final s = c.read(hatimControllerProvider).active!;
    expect(s.dailyTarget, 20);
    expect(s.currentPage, 0);
    expect(s.status, HatimStatus.active);
  });

  test('start by date: günlük sayfa hesaplanır', () async {
    final c = await _container();
    final end = DateTime.now().add(const Duration(days: 30));
    await c
        .read(hatimControllerProvider.notifier)
        .start(startPage: 1, targetEndDate: end);
    final s = c.read(hatimControllerProvider).active!;
    // 604 / 30 ≈ 21
    expect(s.dailyTarget, greaterThanOrEqualTo(20));
    expect(s.dailyTarget, lessThanOrEqualTo(21));
  });

  test('recordPage: gün-içi dedup + currentPage ilerler', () async {
    final c = await _container();
    final n = c.read(hatimControllerProvider.notifier);
    await n.start(startPage: 1, dailyTarget: 5);
    await n.recordPage(1);
    await n.recordPage(2);
    await n.recordPage(2); // dedup → sayılmaz
    final s = c.read(hatimControllerProvider).active!;
    expect(s.readToday(), 2);
    expect(s.currentPage, 2);
  });

  test('recordPage: 604 okununca hatim tamamlanır', () async {
    final c = await _container();
    final n = c.read(hatimControllerProvider.notifier);
    await n.start(startPage: 603, dailyTarget: 5);
    await n.recordPage(603);
    await n.recordPage(604);
    final s = c.read(hatimControllerProvider).active!;
    expect(s.status, HatimStatus.completed);
    expect(s.currentPage, 604);
    expect(s.completedDate, isNotNull);
  });

  test('startPage>1 ile tamamlanma (rule 5): 604 yeter', () async {
    final c = await _container();
    final n = c.read(hatimControllerProvider.notifier);
    await n.start(startPage: 600, dailyTarget: 5);
    for (var p = 600; p <= 604; p++) {
      await n.recordPage(p);
    }
    final s = c.read(hatimControllerProvider).active!;
    expect(s.status, HatimStatus.completed);
    expect(s.startPage, 600); // başlangıç korunur (kutlama önerisi için)
  });

  test('archiveCompleted: tamamlananı geçmişe taşır', () async {
    final c = await _container();
    final n = c.read(hatimControllerProvider.notifier);
    await n.start(startPage: 604, dailyTarget: 5);
    await n.recordPage(604);
    await n.archiveCompleted();
    final d = c.read(hatimControllerProvider);
    expect(d.active, isNull);
    expect(d.history.length, 1);
    expect(d.history.first.status, HatimStatus.completed);
  });

  test('addPagesManual: currentPage ilerler, bugüne işlenir', () async {
    final c = await _container();
    final n = c.read(hatimControllerProvider.notifier);
    await n.start(startPage: 1, dailyTarget: 20);
    await n.addPagesManual(5);
    final s = c.read(hatimControllerProvider).active!;
    expect(s.currentPage, 5);
    expect(s.readToday(), 5);
  });

  test('abandon: aktif yok + geçmişte abandoned', () async {
    final c = await _container();
    final n = c.read(hatimControllerProvider.notifier);
    await n.start(startPage: 1, dailyTarget: 20);
    await n.abandon();
    final d = c.read(hatimControllerProvider);
    expect(d.active, isNull);
    expect(d.history.first.status, HatimStatus.abandoned);
  });

  test('persistans: yeniden okununca durum korunur', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c1 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    await c1
        .read(hatimControllerProvider.notifier)
        .start(startPage: 10, dailyTarget: 15);
    await c1.read(hatimControllerProvider.notifier).recordPage(10);
    // Aynı prefs ile yeni container → state prefs'ten okunur.
    final c2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    final s = c2.read(hatimControllerProvider).active!;
    expect(s.startPage, 10);
    expect(s.currentPage, 10);
    expect(s.dailyTarget, 15);
  });
}
