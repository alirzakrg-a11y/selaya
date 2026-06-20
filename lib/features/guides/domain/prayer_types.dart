import 'package:flutter/material.dart';

/// Bir namaz çeşidi — Namaz Rehberi'nde kategorize gösterilir (rekât + vakit +
/// kısa açıklama). İçerik geneldir; ayrıntı için Diyanet İlmihali esas alınır.
class PrayerType {
  final String category; // 'farz' | 'vacip' | 'nafile' | 'ozel'
  final String nameTr, nameEn;
  final String rakats; // "2 Sünnet + 2 Farz" — rakam ağırlıklı, dilden bağımsız
  final String whenTr, whenEn;
  final String descTr, descEn;
  final IconData icon;
  const PrayerType(this.category, this.nameTr, this.nameEn, this.rakats,
      this.whenTr, this.whenEn, this.descTr, this.descEn, this.icon);
  String name(String l) => l == 'tr' ? nameTr : nameEn;
  String whenText(String l) => l == 'tr' ? whenTr : whenEn;
  String desc(String l) => l == 'tr' ? descTr : descEn;
}

const prayerCategoriesTr = {
  'farz': '5 Vakit Namaz',
  'vacip': 'Vacip & Haftalık',
  'nafile': 'Nafile Namazlar',
  'ozel': 'Özel Namazlar',
};
const prayerCategoriesEn = {
  'farz': 'The Five Daily Prayers',
  'vacip': 'Wajib & Weekly',
  'nafile': 'Voluntary (Nafilah)',
  'ozel': 'Special Prayers',
};
const prayerCategoryOrder = ['farz', 'vacip', 'nafile', 'ozel'];

const prayerTypes = <PrayerType>[
  // ---------- 5 VAKİT (FARZ) ----------
  PrayerType(
      'farz',
      'Sabah Namazı',
      'Fajr',
      '2 Sünnet + 2 Farz',
      'Fecr-i sadık (şafak) ile güneş doğmadan önce',
      'From true dawn until just before sunrise',
      'Günün ilk namazı. Sünneti çok faziletlidir; Peygamberimiz onu yolculukta bile terk etmemiştir.',
      'The first prayer of the day. Its sunnah is highly virtuous; the Prophet kept it even while travelling.',
      Icons.wb_twilight_rounded),
  PrayerType(
      'farz',
      'Öğle Namazı',
      'Dhuhr',
      '4 Sünnet + 4 Farz + 2 Sünnet',
      'Güneş tepe noktasını geçtikten sonra ikindiye kadar',
      'After the sun passes its zenith until Asr',
      'Gündüzün ortasında kılınır; ilk ve son sünnetleriyle birlikte on rekâttır.',
      'Prayed at midday; ten rakahs together with its sunnah prayers.',
      Icons.light_mode_rounded),
  PrayerType(
      'farz',
      'İkindi Namazı',
      'Asr',
      '4 Sünnet (gayrımüekked) + 4 Farz',
      'Öğleden sonra, güneş batmadan önce',
      'In the afternoon, before sunset',
      'Kur\'an\'da özellikle korunması istenen "orta namaz" olarak yorumlanır.',
      'Often interpreted as the "middle prayer" the Quran asks us to especially guard.',
      Icons.wb_sunny_rounded),
  PrayerType(
      'farz',
      'Akşam Namazı',
      'Maghrib',
      '3 Farz + 2 Sünnet',
      'Güneş battıktan hemen sonra, yatsıya kadar',
      'Right after sunset, until Isha',
      'Vakti en kısa namazdır; güneş batar batmaz kılınması tavsiye edilir.',
      'Has the shortest window; recommended to pray soon after sunset.',
      Icons.nights_stay_rounded),
  PrayerType(
      'farz',
      'Yatsı Namazı',
      'Isha',
      '4 Sünnet + 4 Farz + 2 Sünnet',
      'Akşamın kızıllığı kaybolduktan sonra gece boyunca',
      'After the twilight fades, throughout the night',
      'Günün son farz namazı. Ardından vitir namazı kılınır.',
      'The last obligatory prayer of the day; followed by the Witr prayer.',
      Icons.bedtime_rounded),
  // ---------- VACİP & HAFTALIK ----------
  PrayerType(
      'vacip',
      'Vitir Namazı',
      'Witr',
      '3 Rekât (Vacip)',
      'Yatsıdan sonra, gecenin son namazı olarak',
      'After Isha, as the last prayer of the night',
      'Üçüncü rekâtta Kunut duaları okunur. Gece kalkamayacağından endişe eden kişi, vitri yatsıdan hemen sonra kılar.',
      'Qunut supplications are recited in the third rakah. Pray it after Isha if you may not wake at night.',
      Icons.brightness_3_rounded),
  PrayerType(
      'vacip',
      'Cuma Namazı',
      'Jumu\'ah',
      '4 Sünnet + 2 Farz (hutbeli) + 4 Sünnet',
      'Cuma günü öğle vaktinde, cemaatle',
      'Friday at noon, in congregation',
      'Hür, mukim, mazeretsiz erkeklere farzdır; hutbe ve cemaat şarttır. Öğle namazının yerine geçer.',
      'Obligatory for free, resident men without excuse; a sermon and congregation are required. It replaces Dhuhr.',
      Icons.groups_rounded),
  // ---------- NAFİLE ----------
  PrayerType(
      'nafile',
      'Teheccüd',
      'Tahajjud',
      '2 – 8 Rekât (ikişer)',
      'Gece bir miktar uyuduktan sonra, seher vaktinde',
      'After sleeping part of the night, before dawn',
      'Gece namazı. Seherde kılınıp ardından dua/istiğfar edilmesi çok faziletlidir.',
      'The night prayer. Praying it before dawn with supplication and istighfar is highly virtuous.',
      Icons.dark_mode_rounded),
  PrayerType(
      'nafile',
      'Kuşluk (Duhâ)',
      'Duha',
      '2 – 8 Rekât',
      'Güneş bir mızrak boyu yükseldikten sonra öğleye kadar',
      'After the sun has risen well, until just before noon',
      'Şükür namazı olarak bilinir; bedendeki her eklem için bir sadaka yerine geçtiği bildirilmiştir.',
      'Known as the prayer of gratitude; said to suffice as a charity for every joint in the body.',
      Icons.wb_sunny_outlined),
  PrayerType(
      'nafile',
      'Evvâbîn',
      'Awwabin',
      '6 Rekât',
      'Akşam namazının farz ve sünnetinden sonra',
      'After the obligatory and sunnah of Maghrib',
      'Tövbe edenlerin namazı olarak anılır; akşamla yatsı arasında kılınır.',
      'Called the prayer of the oft-returning (penitent); prayed between Maghrib and Isha.',
      Icons.volunteer_activism_rounded),
  PrayerType(
      'nafile',
      'Tahiyyetü\'l-Mescid',
      'Tahiyyat al-Masjid',
      '2 Rekât',
      'Camiye girince, oturmadan önce',
      'On entering the mosque, before sitting',
      '"Mescidi selamlama" namazıdır; mescide hürmeten kılınması müstehaptır.',
      'The "greeting of the mosque" prayer; recommended out of respect for the mosque.',
      Icons.mosque_rounded),
  PrayerType(
      'nafile',
      'İstihare',
      'Istikhara',
      '2 Rekât',
      'Bir işin hayırlı olup olmadığında tereddütte iken',
      'When uncertain whether a matter is good',
      'İki rekâttan sonra istihare duası okunur; gönle doğan rahatlık işaret sayılır, istişareyle birlikte yapılır.',
      'After two rakahs, the Istikhara dua is recited; the ease that comes to the heart is a sign, done with consultation.',
      Icons.help_outline_rounded),
  // ---------- ÖZEL ----------
  PrayerType(
      'ozel',
      'Bayram Namazı',
      'Eid Prayer',
      '2 Rekât (zevâid tekbirli)',
      'Ramazan ve Kurban Bayramı sabahı, cemaatle',
      'Eid al-Fitr & al-Adha morning, in congregation',
      'Her rekâtta fazladan üçer tekbir vardır; namazdan sonra hutbe okunur.',
      'There are three extra takbirs in each rakah; a sermon follows the prayer.',
      Icons.celebration_rounded),
  PrayerType(
      'ozel',
      'Cenaze Namazı',
      'Funeral Prayer',
      '4 Tekbir (rükûsuz, secdesiz)',
      'Vefat eden Müslüman için, defin öncesi',
      'For a deceased Muslim, before burial',
      'Farz-ı kifâyedir; ayakta dört tekbirle kılınır, üçüncüden sonra cenaze duası okunur.',
      'A communal obligation; prayed standing with four takbirs, with a supplication for the deceased after the third.',
      Icons.local_florist_rounded),
  PrayerType(
      'ozel',
      'Teravih',
      'Tarawih',
      '20 Rekât (ikişer/dörder)',
      'Ramazan gecelerinde, yatsıdan sonra vitirden önce',
      'Ramadan nights, after Isha before Witr',
      'Ramazana özgü sünnet bir namazdır; cemaatle kılınması çok faziletlidir.',
      'A sunnah prayer specific to Ramadan; praying it in congregation is highly virtuous.',
      Icons.star_rounded),
];
