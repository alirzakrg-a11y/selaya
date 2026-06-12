import '../../../core/di/providers.dart';

/// Medine mushafı (KFGQPC, 604 sayfa) sayfa meta verisi + görsel kaynağı.
/// Sayfa görselleri: Five-Prayers/quran-pages (GitHub) — jsDelivr CDN üzerinden.
/// suraStartPage/juzStartPage api.alquran.cloud/v1/meta'dan üretildi ve
/// doğrulandı (Fâtiha=1, Bakara=2, Yâsîn=440, Mülk=562, Nâs=604).

const List<int> suraStartPage = [1, 2, 50, 77, 106, 128, 151, 177, 187, 208, 221, 235, 249, 255, 262, 267, 282, 293, 305, 312, 322, 332, 342, 350, 359, 367, 377, 385, 396, 404, 411, 415, 418, 428, 434, 440, 446, 453, 458, 467, 477, 483, 489, 496, 499, 502, 507, 511, 515, 518, 520, 523, 526, 528, 531, 534, 537, 542, 545, 549, 551, 553, 554, 556, 558, 560, 562, 564, 566, 568, 570, 572, 574, 575, 577, 578, 580, 582, 583, 585, 586, 587, 587, 589, 590, 591, 591, 592, 593, 594, 595, 595, 596, 596, 597, 597, 598, 598, 599, 599, 600, 600, 601, 601, 601, 602, 602, 602, 603, 603, 603, 604, 604, 604];

const List<int> juzStartPage = [1, 22, 42, 62, 82, 102, 121, 142, 162, 182, 201, 222, 242, 262, 282, 302, 322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562, 582];

const int mushafPageCount = 604;

String mushafPageUrl(int page) =>
    'https://cdn.jsdelivr.net/gh/Five-Prayers/quran-pages@main/quran_pages/$page.png';

/// Surenin başladığı mushaf sayfası (1-604).
int pageForSurah(int surah) => suraStartPage[(surah - 1).clamp(0, 113)];

/// Sayfadaki (ilk) sure numarası — başlıkta sure adı göstermek için.
int surahForPage(int page) {
  var s = 1;
  for (var i = 0; i < suraStartPage.length; i++) {
    if (suraStartPage[i] <= page) s = i + 1;
  }
  return s;
}

/// Sayfanın cüz numarası (1-30).
int juzForPage(int page) {
  var j = 1;
  for (var i = 0; i < juzStartPage.length; i++) {
    if (juzStartPage[i] <= page) j = i + 1;
  }
  return j;
}

/// Kaldığı sayfa anahtarı (mushaf kaldığın yerden devam).
const String mushafLastPageKey = PrefKeys.mushafLastPage;

/// Surenin mushaf sayfa aralığı: (başlangıç, bitiş) — sure-içi "x/y" sayacı için.
(int, int) surahPageSpan(int surah) {
  final s = surah.clamp(1, 114);
  final start = suraStartPage[s - 1];
  final end = s < 114 ? (suraStartPage[s] - 1).clamp(start, 604) : 604;
  return (start, end);
}

/// Cüzün mushaf sayfa aralığı: (başlangıç, bitiş) — cüz-içi "i/j" sayacı için.
(int, int) juzPageSpan(int juz) {
  final j = juz.clamp(1, 30);
  final start = juzStartPage[j - 1];
  final end = j < 30 ? (juzStartPage[j] - 1).clamp(start, 604) : 604;
  return (start, end);
}
