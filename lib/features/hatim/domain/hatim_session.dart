import 'dart:convert';

/// Mushaf toplam sayfa (Medine Mushafı).
const int hatimPageTotal = 604;

/// Gün anahtarı: "YYYY-MM-DD" (yerel). readPagesByDay + dedup bunu kullanır.
String hatimDateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

enum HatimStatus { active, completed, abandoned }

/// Tek bir hatim oturumu. [readPagesByDay] gün → o gün OKUNAN sayfa numaraları
/// listesidir (gün-içi dedup + cihazlar arası union bunun üstünden yürür;
/// günlük okunan sayı = listenin uzunluğu).
class HatimSession {
  final String id;
  final DateTime startDate;
  final int startPage;
  final int dailyTarget;
  final DateTime? targetEndDate;

  /// Okunan en ileri sayfa (mushaftaki konum). 604'e ulaşınca hatim biter.
  final int currentPage;
  final Map<String, List<int>> readPagesByDay;
  final DateTime? completedDate;
  final HatimStatus status;

  const HatimSession({
    required this.id,
    required this.startDate,
    required this.startPage,
    required this.dailyTarget,
    this.targetEndDate,
    required this.currentPage,
    this.readPagesByDay = const {},
    this.completedDate,
    this.status = HatimStatus.active,
  });

  HatimSession copyWith({
    int? currentPage,
    Map<String, List<int>>? readPagesByDay,
    DateTime? completedDate,
    HatimStatus? status,
  }) =>
      HatimSession(
        id: id,
        startDate: startDate,
        startPage: startPage,
        dailyTarget: dailyTarget,
        targetEndDate: targetEndDate,
        currentPage: currentPage ?? this.currentPage,
        readPagesByDay: readPagesByDay ?? this.readPagesByDay,
        completedDate: completedDate ?? this.completedDate,
        status: status ?? this.status,
      );

  /// Belirli günün okunan sayfa listesi (dedup için).
  List<int> pagesOn(DateTime d) => readPagesByDay[hatimDateKey(d)] ?? const [];

  /// Bugün okunan sayfa sayısı.
  int readToday([DateTime? now]) => pagesOn(now ?? DateTime.now()).length;

  /// İlerleme oranı = mushaftaki konum (currentPage / 604).
  double get percent => (currentPage / hatimPageTotal).clamp(0.0, 1.0);

  int get pagesLeft => (hatimPageTotal - currentPage).clamp(0, hatimPageTotal);

  /// Son 7 günün ortalama günlük sayfası; hiç veri yoksa hedef tempo.
  double recentDailyAvg([DateTime? now]) {
    final base = now ?? DateTime.now();
    var sum = 0;
    for (var i = 0; i < 7; i++) {
      sum += pagesOn(base.subtract(Duration(days: i))).length;
    }
    final avg = sum / 7.0;
    return avg > 0 ? avg : dailyTarget.toDouble();
  }

  /// Tahmini bitiş tarihi (mevcut tempoyla). Tamamlanmışsa completedDate.
  DateTime estimatedEnd([DateTime? now]) {
    if (status == HatimStatus.completed && completedDate != null) {
      return completedDate!;
    }
    final base = now ?? DateTime.now();
    final avg = recentDailyAvg(base);
    final days = avg <= 0 ? 999 : (pagesLeft / avg).ceil();
    return DateTime(base.year, base.month, base.day).add(Duration(days: days));
  }

  /// Üst üste GÜNLÜK HEDEFİ tutturulan gün serisi. Bugün hedefe ulaşılmadıysa
  /// (gün henüz bitmedi) dünden geriye sayar — ibadet takibi ile aynı dil.
  int streak([DateTime? now]) {
    if (dailyTarget <= 0) return 0;
    final base = now ?? DateTime.now();
    var start = 0;
    if (readToday(base) < dailyTarget) start = 1; // bugün eksikse seri kırılmaz
    var s = 0;
    for (var i = start;; i++) {
      final c = pagesOn(base.subtract(Duration(days: i))).length;
      if (c >= dailyTarget) {
        s++;
      } else {
        break;
      }
    }
    return s;
  }

  /// Toplam gün sayısı (başlangıçtan bitişe/bugüne).
  int get dayCount {
    final end = completedDate ?? DateTime.now();
    return end.difference(startDate).inDays + 1;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startDate': startDate.toIso8601String(),
        'startPage': startPage,
        'dailyTarget': dailyTarget,
        'targetEndDate': targetEndDate?.toIso8601String(),
        'currentPage': currentPage,
        'readPagesByDay': readPagesByDay,
        'completedDate': completedDate?.toIso8601String(),
        'status': status.name,
      };

  factory HatimSession.fromJson(Map<String, dynamic> j) {
    final raw = (j['readPagesByDay'] as Map?) ?? const {};
    final map = <String, List<int>>{};
    raw.forEach((k, v) {
      if (v is List) {
        map[k as String] = v.map((e) => (e as num).toInt()).toList();
      }
    });
    DateTime? parse(Object? s) =>
        s == null ? null : DateTime.tryParse(s.toString());
    return HatimSession(
      id: (j['id'] ?? '').toString(),
      startDate: parse(j['startDate']) ?? DateTime.now(),
      startPage: (j['startPage'] as num?)?.toInt() ?? 1,
      dailyTarget: (j['dailyTarget'] as num?)?.toInt() ?? 20,
      targetEndDate: parse(j['targetEndDate']),
      currentPage: (j['currentPage'] as num?)?.toInt() ?? 0,
      readPagesByDay: map,
      completedDate: parse(j['completedDate']),
      status: HatimStatus.values.firstWhere(
          (s) => s.name == j['status'], orElse: () => HatimStatus.active),
    );
  }
}

/// Tek aktif hatim + tamamlanan/bırakılan geçmiş. Tek JSON olarak saklanır.
class HatimData {
  final HatimSession? active;
  final List<HatimSession> history;
  const HatimData({this.active, this.history = const []});

  Map<String, dynamic> toJson() => {
        'active': active?.toJson(),
        'history': history.map((s) => s.toJson()).toList(),
      };

  factory HatimData.fromJson(Map<String, dynamic> j) => HatimData(
        active: j['active'] == null
            ? null
            : HatimSession.fromJson(Map<String, dynamic>.from(j['active'] as Map)),
        history: ((j['history'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => HatimSession.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  String encode() => jsonEncode(toJson());

  static HatimData decode(String? s) {
    if (s == null || s.isEmpty) return const HatimData();
    try {
      return HatimData.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const HatimData();
    }
  }
}

/// SENKRON birleştirme: [local] (bu cihazın merge ÖNCESİ hatim'i) ile [remote]
/// (buluttan uygulanmış) durumu birleştir.
///   • Aynı id'li aktif oturumda readPagesByDay GÜN GÜN UNION (sayfa numarası
///     seti); currentPage = max. Diğer alanlar bulut (remote) kazanır.
///   • Geçmiş listesi id'ye göre union.
HatimData mergeHatimData(HatimData local, HatimData remote) {
  HatimSession? active;
  final la = local.active, ra = remote.active;
  if (la != null && ra != null && la.id == ra.id) {
    final keys = <String>{...la.readPagesByDay.keys, ...ra.readPagesByDay.keys};
    final map = <String, List<int>>{};
    for (final k in keys) {
      final set = <int>{...?la.readPagesByDay[k], ...?ra.readPagesByDay[k]};
      map[k] = set.toList()..sort();
    }
    active = ra.copyWith(
      readPagesByDay: map,
      currentPage:
          la.currentPage > ra.currentPage ? la.currentPage : ra.currentPage,
    );
  } else {
    // id eşleşmiyor → bulut aktifini al; bulut yoksa yereli koru.
    active = ra ?? la;
  }
  final byId = <String, HatimSession>{};
  for (final s in [...remote.history, ...local.history]) {
    byId.putIfAbsent(s.id, () => s);
  }
  final hist = byId.values.toList()
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
  return HatimData(active: active, history: hist);
}
