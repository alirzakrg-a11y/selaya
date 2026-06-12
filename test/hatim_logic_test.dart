import 'package:flutter_test/flutter_test.dart';
import 'package:selaya/features/hatim/domain/hatim_session.dart';

HatimSession _s({
  int startPage = 1,
  int dailyTarget = 20,
  int currentPage = 0,
  Map<String, List<int>>? days,
  HatimStatus status = HatimStatus.active,
}) =>
    HatimSession(
      id: 'h1',
      startDate: DateTime(2026, 6, 1),
      startPage: startPage,
      dailyTarget: dailyTarget,
      currentPage: currentPage,
      readPagesByDay: days ?? const {},
      status: status,
    );

void main() {
  test('percent + pagesLeft mushaf konumuna göre', () {
    final s = _s(currentPage: 302);
    expect((s.percent * 100).round(), 50);
    expect(s.pagesLeft, 302);
  });

  test('JSON round-trip readPagesByDay List<int> korunur', () {
    final s = _s(currentPage: 5, days: {
      '2026-06-10': [1, 2, 3],
      '2026-06-11': [4, 5],
    });
    final back = HatimSession.fromJson(s.toJson());
    expect(back.readPagesByDay['2026-06-10'], [1, 2, 3]);
    expect(back.readPagesByDay['2026-06-11'], [4, 5]);
    expect(back.currentPage, 5);
  });

  test('readToday = günün listesinin uzunluğu', () {
    final k = hatimDateKey(DateTime.now());
    final s = _s(days: {
      k: [10, 11, 12]
    });
    expect(s.readToday(), 3);
  });

  test('streak: bugün eksikse dünden geriye, üst üste hedef', () {
    final now = DateTime.now();
    String key(int back) => hatimDateKey(now.subtract(Duration(days: back)));
    // dün ve evvelki gün 20'şer (hedef), bugün eksik → seri 2 (bugün saymaz)
    final s = _s(dailyTarget: 20, days: {
      key(1): List.generate(20, (i) => i + 1),
      key(2): List.generate(20, (i) => i + 100),
      key(0): [1, 2], // bugün eksik
    });
    expect(s.streak(), 2);
  });

  test('mergeHatimData: aynı gün UNION (overwrite değil), currentPage max', () {
    final local = HatimData(
        active: _s(currentPage: 40, days: {
      '2026-06-10': [1, 2, 3], // yerelde 1-3
      '2026-06-11': [10],
    }));
    final remote = HatimData(
        active: _s(currentPage: 55, days: {
      '2026-06-10': [3, 4, 5], // bulutta 3-5 (3 ortak)
      '2026-06-12': [20],
    }));
    final m = mergeHatimData(local, remote);
    final days = m.active!.readPagesByDay;
    // 2026-06-10 union = {1,2,3,4,5}
    expect(days['2026-06-10'], [1, 2, 3, 4, 5]);
    expect(days['2026-06-11'], [10]); // yalnız yerel
    expect(days['2026-06-12'], [20]); // yalnız bulut
    expect(m.active!.currentPage, 55); // max(40,55)
  });

  test('mergeHatimData: farklı id → bulut aktifini al', () {
    final local = HatimData(active: _s().copyWith());
    final remote = HatimData(
        active: HatimSession(
            id: 'h2',
            startDate: DateTime(2026, 6, 5),
            startPage: 1,
            dailyTarget: 10,
            currentPage: 3));
    final m = mergeHatimData(local, remote);
    expect(m.active!.id, 'h2');
  });

  test('recentDailyAvg: veri yoksa hedef tempo', () {
    final s = _s(dailyTarget: 15);
    expect(s.recentDailyAvg(), 15.0);
  });

  test('estimatedEnd: tempoyla ileri tarih', () {
    final now = DateTime.now();
    final s = _s(currentPage: 584, dailyTarget: 20, days: {
      hatimDateKey(now): List.generate(20, (i) => i + 560),
    });
    // 20 kaldı, günde ~ (20/7≈2.9) ... avg>0 → birkaç gün sonra
    expect(s.estimatedEnd().isAfter(now), true);
  });
}
