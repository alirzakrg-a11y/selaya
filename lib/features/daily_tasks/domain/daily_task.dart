import 'package:flutter/material.dart';

/// A daily-task definition from the in-app task library (#18 "görev kütüphanesi").
/// Tasks are bilingual inline (same pattern as CalcMethod) and may deep-link to
/// the related feature. IDs are STABLE — they key the completion log, so never
/// rename one (add new ones instead).
@immutable
class DailyTaskDef {
  final String id;
  final String titleTr;
  final String titleEn;
  final IconData icon;

  /// Optional route to the related feature (null = a reflective task with no
  /// in-app destination, e.g. "do a kindness").
  final String? route;

  /// Dhikr görevleri için: açınca zikir HAZIR seçili gelsin (deep-link param).
  final String? zikirAr;
  final String? zikirName;
  final int? zikirTarget;

  const DailyTaskDef(this.id, this.titleTr, this.titleEn, this.icon,
      {this.route, this.zikirAr, this.zikirName, this.zikirTarget});

  String title(String lang) => lang == 'tr' ? titleTr : titleEn;

  /// Açılınca gidilecek rota — dhikr görevlerinde zikir parametreli (preset
  /// hazır seçili gelsin). Eskiden düz "/dhikr" gidiyordu → zikir seçilmiyordu.
  String? get navRoute {
    if (zikirAr != null) {
      // &task=<id> → zikir hedefe ulaşınca dhikr ekranı bu görevi otomatik
      // "yapıldı" işaretler (③: 100 zikir bitince görev kendiliğinden işaretlensin).
      return '/dhikr?ar=${Uri.encodeComponent(zikirAr!)}'
          '&name=${Uri.encodeComponent(zikirName ?? '')}'
          '&target=${zikirTarget ?? 33}'
          '&task=${Uri.encodeComponent(id)}';
    }
    return route;
  }
}

/// The curated task library. Keep it comfortably larger than the 5 shown per day
/// so the daily set has real variety.
const List<DailyTaskDef> taskLibrary = [
  DailyTaskDef('verse', 'Günün ayetini oku', 'Read the verse of the day',
      Icons.menu_book_rounded, route: '/home'),
  DailyTaskDef('quran10', "Kur'an'dan en az 10 ayet oku",
      'Read at least 10 verses of the Quran', Icons.auto_stories_rounded,
      route: '/quran'),
  DailyTaskDef('tasbih33', '33 defa Sübhânallah de', 'Say Subhanallah 33 times',
      Icons.radio_button_checked,
      route: '/dhikr',
      zikirAr: 'سُبْحَانَ اللّٰهِ',
      zikirName: 'Sübhânallah',
      zikirTarget: 33),
  DailyTaskDef('tahmid33', '33 defa Elhamdülillah de',
      'Say Alhamdulillah 33 times', Icons.brightness_5_rounded,
      route: '/dhikr',
      zikirAr: 'اَلْحَمْدُ لِلّٰهِ',
      zikirName: 'Elhamdülillah',
      zikirTarget: 33),
  DailyTaskDef('tekbir33', '33 defa Allâhu Ekber de',
      'Say Allahu Akbar 33 times', Icons.expand_less_rounded,
      route: '/dhikr',
      zikirAr: 'اَللّٰهُ أَكْبَرُ',
      zikirName: 'Allâhu Ekber',
      zikirTarget: 33),
  DailyTaskDef('tehlil', '100 defa Lâ ilâhe illallah de',
      'Say La ilaha illallah 100 times', Icons.brightness_7_rounded,
      route: '/dhikr',
      zikirAr: 'لَا إِلٰهَ إِلَّا اللّٰهُ',
      zikirName: 'Lâ ilâhe illallah',
      zikirTarget: 100),
  DailyTaskDef('istighfar', '100 defa Estağfirullah de',
      'Say Istighfar 100 times', Icons.spa_rounded,
      route: '/dhikr',
      zikirAr: 'أَسْتَغْفِرُ اللّٰهَ',
      zikirName: 'Estağfirullah',
      zikirTarget: 100),
  DailyTaskDef('salavat', '10 defa salavât getir', 'Send 10 salawat',
      Icons.favorite_rounded,
      route: '/dhikr',
      zikirAr: 'اَللّٰهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ',
      zikirName: 'Salavât',
      zikirTarget: 10),
  DailyTaskDef('dua', 'Bir dua ezberle', 'Memorize a dua',
      Icons.volunteer_activism_rounded, route: '/duas'),
  DailyTaskDef('esma3', "Esmâ-ül Hüsnâ'dan 3 isim öğren",
      'Learn 3 of the Beautiful Names', Icons.auto_awesome_rounded,
      route: '/asma'),
  DailyTaskDef('yasin', "Yâsîn'den bir bölüm oku",
      'Read a section of Surah Yasin', Icons.book_rounded, route: '/yasin'),
  DailyTaskDef('hadith', 'Günün hadisini oku', 'Read the hadith of the day',
      Icons.format_quote_rounded, route: '/home'),
  DailyTaskDef('mosque', 'Bir namazı camide kıl',
      'Pray one prayer at the mosque', Icons.mosque_rounded, route: '/mosques'),
  DailyTaskDef('kindness', 'Bir kişiye iyilik yap', 'Do a kindness for someone',
      Icons.handshake_rounded),
  DailyTaskDef('tefekkur', '5 dakika tefekkür et', 'Reflect for 5 minutes',
      Icons.self_improvement_rounded),
  DailyTaskDef('sadaka', 'Bir sadaka ver', 'Give a charity (sadaqah)',
      Icons.volunteer_activism_rounded),
  DailyTaskDef('nafile', '2 rekât nâfile namaz kıl',
      'Pray 2 rakats of nafilah', Icons.brightness_low_rounded),
  DailyTaskDef('shukr', "Allah'a 3 nimet için şükret",
      'Thank Allah for 3 blessings', Icons.wb_sunny_rounded),
  DailyTaskDef('gossip', 'Bugün dedikodudan uzak dur', 'Avoid gossip today',
      Icons.volume_off_rounded),
  DailyTaskDef('ayetelkursi', "Âyetü'l-Kürsî'yi oku", 'Read Ayat al-Kursi',
      Icons.shield_moon_rounded, route: '/quran-reader/2'),
  DailyTaskDef('mulk', 'Mülk (Tebâreke) sûresini oku', 'Read Surah Al-Mulk',
      Icons.nights_stay_rounded, route: '/quran-reader/67'),
  DailyTaskDef('parents', 'Anne-baban için dua et', 'Pray for your parents',
      Icons.family_restroom_rounded),
  DailyTaskDef('earlyPrayer', 'Bir namazı ilk vaktinde kıl',
      'Pray a prayer at its earliest time', Icons.alarm_on_rounded),
  DailyTaskDef('smile', 'Bir mümine tebessüm et', 'Smile at a believer',
      Icons.sentiment_satisfied_rounded),
  DailyTaskDef('water', 'Birine su veya ikram ver',
      'Offer someone water or a treat', Icons.local_drink_rounded),
  DailyTaskDef('forgive', 'Birini affet, helalleş', 'Forgive someone',
      Icons.healing_rounded),
];

/// The 5 tasks for [date] — STABLE all day, DIFFERENT each day, and identical
/// across devices (a seeded Fisher–Yates by day index; no stored RNG state).
List<DailyTaskDef> dailyTasksFor(DateTime date) {
  final dayIndex = DateTime(date.year, date.month, date.day)
      .difference(DateTime(2020, 1, 1))
      .inDays;
  final pool = List<DailyTaskDef>.from(taskLibrary);
  // Simple LCG seeded by the day index → deterministic per-day shuffle.
  var seed = (dayIndex * 1103515245 + 12345) & 0x7fffffff;
  int nextInt(int bound) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed % bound;
  }

  for (var i = pool.length - 1; i > 0; i--) {
    final j = nextInt(i + 1);
    final tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }
  return pool.take(dailyTaskCount).toList();
}

/// How many tasks are surfaced per day.
const int dailyTaskCount = 8;
