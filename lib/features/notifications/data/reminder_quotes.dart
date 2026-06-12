import 'dart:math';

/// Short, uplifting verses & hadiths shown (at random) as the body of the
/// "X minutes before prayer" reminders. Bilingual inline (TR/EN), matching the
/// established curated-content pattern.
class ReminderQuotes {
  static const _tr = [
    '"Beni anmak için namaz kıl." (Tâhâ, 14)',
    '"Sabır ve namazla yardım isteyin." (Bakara, 45)',
    '"Kalpler ancak Allah\'ı anmakla huzur bulur." (Ra\'d, 28)',
    '"Şüphesiz namaz, müminlere vakitleri belli bir farzdır." (Nisâ, 103)',
    '"Secde et ve yaklaş." (Alak, 19)',
    'Namaz dinin direğidir. (Beyhakî)',
    'Cennetin anahtarı namazdır. (Tirmizî)',
    'Allah katında amellerin en sevimlisi vaktinde kılınan namazdır. (Buhârî)',
    'Beş vakit namaz, aralarındaki günahlara kefarettir. (Müslim)',
    'Kıyamette ilk hesabı sorulacak amel namazdır. (Tirmizî)',
    'Temizlik imanın yarısıdır. (Müslim)',
    'Mü\'minlerin iman bakımından en olgunu, ahlâkı en güzel olanıdır. (Tirmizî)',
  ];

  static const _en = [
    '"Establish prayer for My remembrance." (Ta-Ha, 14)',
    '"Seek help through patience and prayer." (Al-Baqarah, 45)',
    '"In the remembrance of Allah hearts find rest." (Ar-Ra\'d, 28)',
    '"Prayer is decreed upon the believers at fixed times." (An-Nisa, 103)',
    '"Prostrate and draw near." (Al-Alaq, 19)',
    'Prayer is the pillar of religion. (Bayhaqi)',
    'The key to Paradise is prayer. (Tirmidhi)',
    'The most beloved deed to Allah is prayer at its time. (Bukhari)',
    'The five daily prayers expiate the sins between them. (Muslim)',
    'The first deed to be accounted for is prayer. (Tirmidhi)',
    'Cleanliness is half of faith. (Muslim)',
    'The most complete believers in faith are the best in character. (Tirmidhi)',
  ];

  static final _rand = Random();

  /// A random verse/hadith for the given [lang] ('tr' or otherwise English).
  static String random(String lang) {
    final list = lang == 'tr' ? _tr : _en;
    return list[_rand.nextInt(list.length)];
  }
}
