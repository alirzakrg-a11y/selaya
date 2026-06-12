import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/hatim_session.dart';

/// Hatim takibi durumu (aktif oturum + geçmiş). Tamamen yerel
/// (SharedPreferences `hatimState`); girişli kullanıcıda senkron yapısına dahil.
class HatimController extends Notifier<HatimData> {
  @override
  HatimData build() => HatimData.decode(
      ref.read(sharedPreferencesProvider).getString(PrefKeys.hatimState));

  Future<void> _persist(HatimData data) async {
    state = data;
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.hatimState, data.encode());
  }

  /// Yeni hatim başlat. [dailyTarget] verilir VEYA [targetEndDate]'ten hesaplanır.
  /// Aktif hatim varsa önce onu geçmişe (abandoned) at.
  Future<void> start({
    required int startPage,
    int? dailyTarget,
    DateTime? targetEndDate,
  }) async {
    final now = DateTime.now();
    final sp = startPage.clamp(1, hatimPageTotal);
    var target = dailyTarget ?? 0;
    if (target <= 0 && targetEndDate != null) {
      final days = DateTime(targetEndDate.year, targetEndDate.month,
              targetEndDate.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
      final pages = (hatimPageTotal - sp + 1).clamp(1, hatimPageTotal);
      target = days <= 0 ? pages : (pages / days).ceil();
    }
    if (target <= 0) target = 20;
    final session = HatimSession(
      id: 'h${now.millisecondsSinceEpoch}',
      startDate: now,
      startPage: sp,
      dailyTarget: target,
      targetEndDate: targetEndDate,
      currentPage: sp - 1, // startPage henüz okunmadı
      readPagesByDay: const {},
      status: HatimStatus.active,
    );
    final hist = state.active == null
        ? state.history
        : [
            state.active!.copyWith(
                status: HatimStatus.abandoned, completedDate: now),
            ...state.history,
          ];
    await _persist(HatimData(active: session, history: hist));
  }

  /// Mushafta bir sayfa OKUNDU (ileri yön + ≥3 sn mushaf tarafında garanti
  /// edilir; geriye gidiş orada elenir). Gün-içi dedup (aynı sayfa aynı gün iki
  /// kez sayılmaz) BURADA listeyle yapılır. 604 kaydedilince hatim tamamlanır.
  Future<void> recordPage(int page) async {
    final s = state.active;
    if (s == null || s.status != HatimStatus.active) return;
    if (page < 1 || page > hatimPageTotal) return;
    final key = hatimDateKey(DateTime.now());
    final today = List<int>.from(s.readPagesByDay[key] ?? const []);
    if (today.contains(page)) return; // gün-içi dedup
    today.add(page);
    final map = Map<String, List<int>>.from(s.readPagesByDay)..[key] = today;
    final newCurrent = page > s.currentPage ? page : s.currentPage;
    var updated = s.copyWith(readPagesByDay: map, currentPage: newCurrent);
    if (newCurrent >= hatimPageTotal) {
      // currentPage 604'e ulaşıp 604 okundu → tamamlandı (startPage ne olursa
      // olsun). active=completed kalır → ekran kutlamayı gösterir, sonra arşivler.
      updated = updated.copyWith(
          status: HatimStatus.completed,
          completedDate: DateTime.now(),
          currentPage: hatimPageTotal);
    }
    await _persist(HatimData(active: updated, history: state.history));
  }

  /// Mushaf dışı okuma için elle: currentPage'den sonraki [n] sayfayı bugüne
  /// işle (ilerlemeyi öne taşır).
  Future<void> addPagesManual(int n) async {
    final s = state.active;
    if (s == null || s.status != HatimStatus.active || n <= 0) return;
    final key = hatimDateKey(DateTime.now());
    final today = List<int>.from(s.readPagesByDay[key] ?? const []);
    var cur = s.currentPage;
    for (var i = 0; i < n && cur < hatimPageTotal; i++) {
      cur++;
      if (!today.contains(cur)) today.add(cur);
    }
    final map = Map<String, List<int>>.from(s.readPagesByDay)..[key] = today;
    var updated = s.copyWith(currentPage: cur, readPagesByDay: map);
    if (cur >= hatimPageTotal) {
      updated = updated.copyWith(
          status: HatimStatus.completed, completedDate: DateTime.now());
    }
    await _persist(HatimData(active: updated, history: state.history));
  }

  /// Tamamlanan oturumu geçmişe taşı (kutlama ekranı "Tamam"da çağırır).
  Future<void> archiveCompleted() async {
    final s = state.active;
    if (s == null || s.status != HatimStatus.completed) return;
    await _persist(HatimData(active: null, history: [s, ...state.history]));
  }

  /// Hatimden vazgeç → geçmişe abandoned olarak taşı.
  Future<void> abandon() async {
    final s = state.active;
    if (s == null) return;
    await _persist(HatimData(
      active: null,
      history: [
        s.copyWith(status: HatimStatus.abandoned, completedDate: DateTime.now()),
        ...state.history,
      ],
    ));
  }

  /// SENKRON: buluttan uygulanan duruma, merge ÖNCESİ yerel hatim'i gün-union
  /// ile kat. [localJson] = _clearLocal'dan önce yakalanan yerel hatimState.
  Future<void> mergeFromLocal(String? localJson) async {
    final merged = mergeHatimData(HatimData.decode(localJson), state);
    await _persist(merged);
  }
}

final hatimControllerProvider =
    NotifierProvider<HatimController, HatimData>(HatimController.new);
