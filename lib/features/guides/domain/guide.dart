import 'package:flutter/material.dart';

/// A single illustrated step in a how-to guide (#16/#17). Bilingual inline
/// (the established pattern for curated content). Each step carries a meaningful
/// [icon] the screen renders in a styled badge; a real photo can be swapped in
/// later by adding an image field without touching the data below.
class GuideStep {
  final String tt, et, tb, eb; // title TR/EN, body TR/EN
  final IconData icon;
  final String? image; // optional illustration asset shown above the step
  const GuideStep(this.tt, this.et, this.tb, this.eb, this.icon, {this.image});
  String title(String l) => l == 'tr' ? tt : et;
  String body(String l) => l == 'tr' ? tb : eb;
  GuideStep withImage(String? img) =>
      GuideStep(tt, et, tb, eb, icon, image: img);
}

/// A labelled bullet-list section (farzlar / hatalar / bozanlar …).
class GuideSection {
  final String tt, et;
  final IconData icon;
  final List<String> tr, en;
  const GuideSection(this.tt, this.et, this.icon, this.tr, this.en);
  String title(String l) => l == 'tr' ? tt : et;
  List<String> items(String l) => l == 'tr' ? tr : en;
}

/// A complete guide: intro + numbered steps + extra sections.
class Guide {
  final String tt, et, it, ie; // title TR/EN, intro TR/EN
  final IconData icon;
  final List<GuideStep> steps;
  final List<GuideSection> sections;
  final String st, se; // kaynak/source TR/EN
  const Guide(this.tt, this.et, this.it, this.ie, this.icon, this.steps,
      this.sections, {this.st = '', this.se = ''});
  String title(String l) => l == 'tr' ? tt : et;
  String intro(String l) => l == 'tr' ? it : ie;
  String source(String l) => l == 'tr' ? st : se;
}

// ── #16 Abdest Rehberi ───────────────────────────────────────────────────
const abdestGuide = Guide(
  'Abdest Rehberi',
  'Wudu Guide',
  'Abdest, namaz ve diğer ibadetler için gerekli olan temizliktir. Aşağıda adım adım abdestin nasıl alınacağı anlatılmıştır.',
  'Wudu (ablution) is the purification required for prayer and other acts of worship. Below is a step-by-step guide.',
  Icons.water_drop_rounded,
  [
    GuideStep('Niyet ve Besmele', 'Intention & Basmala',
        'Abdest almaya niyet edip "Eûzü billâhi mineşşeytânirracîm, Bismillâhirrahmânirrahîm" denir.',
        'Make the intention for wudu and say the Basmala.',
        Icons.favorite_rounded,
        image: 'assets/images/guides/abdest/abdest_01.webp'),
    GuideStep('Elleri yıkamak', 'Wash the hands',
        'Eller bileklere kadar, parmak araları dâhil 3 kez yıkanır.',
        'Wash both hands up to the wrists, including between the fingers, 3 times.',
        Icons.wash_rounded,
        image: 'assets/images/guides/abdest/abdest_02.webp'),
    GuideStep('Ağza su vermek (Mazmaza)', 'Rinse the mouth',
        'Sağ avuçla ağza 3 kez su alınıp çalkalanır.',
        'Take water into the mouth and rinse 3 times.',
        Icons.water_drop_rounded,
        image: 'assets/images/guides/abdest/abdest_03.webp'),
    GuideStep('Burna su vermek (İstinşak)', 'Rinse the nose',
        'Sağ elle burna 3 kez su çekilir, sol elle temizlenir.',
        'Draw water into the nose 3 times and clean with the left hand.',
        Icons.air_rounded,
        image: 'assets/images/guides/abdest/abdest_04.webp'),
    GuideStep('Yüzü yıkamak (Farz)', 'Wash the face (obligatory)',
        'Alın saç bitiminden çene altına, bir kulaktan diğer kulağa kadar yüz 3 kez yıkanır.',
        'Wash the whole face from forehead to chin and ear to ear, 3 times.',
        Icons.face_retouching_natural_rounded,
        image: 'assets/images/guides/abdest/abdest_05.webp'),
    GuideStep('Sağ kolu yıkamak (Farz)', 'Wash the right arm (obligatory)',
        'Sağ kol parmak uçlarından dirsekle birlikte 3 kez yıkanır.',
        'Wash the right arm including the elbow, 3 times.',
        Icons.back_hand_rounded,
        image: 'assets/images/guides/abdest/abdest_06.webp'),
    GuideStep('Sol kolu yıkamak (Farz)', 'Wash the left arm (obligatory)',
        'Sol kol parmak uçlarından dirsekle birlikte 3 kez yıkanır.',
        'Wash the left arm including the elbow, 3 times.',
        Icons.front_hand_rounded,
        image: 'assets/images/guides/abdest/abdest_07.webp'),
    GuideStep('Başı mesh etmek (Farz)', 'Wipe the head (obligatory)',
        'Islak elle başın en az dörtte biri (tercihen tamamı) bir kez mesh edilir.',
        'With wet hands, wipe at least a quarter (preferably all) of the head once.',
        Icons.psychology_rounded,
        image: 'assets/images/guides/abdest/abdest_08.webp'),
    GuideStep('Kulakları mesh etmek', 'Wipe the ears',
        'Eller yeniden ıslatılır; şehadet parmaklarıyla kulakların içi, başparmaklarla kulakların arkası (dışı) bir kez mesh edilir.',
        'Re-wet the hands; with the index fingers wipe the inside of the ears and with the thumbs wipe behind the ears, once.',
        Icons.hearing_rounded,
        image: 'assets/images/guides/abdest/abdest_09.webp'),
    GuideStep('Boynu mesh etmek', 'Wipe the neck',
        'Islak ellerin tersiyle (dış yüzüyle) boyun bir kez mesh edilir.',
        'With the backs of the wet hands, wipe the neck once.',
        Icons.cleaning_services_rounded,
        image: 'assets/images/guides/abdest/abdest_13.webp'),
    GuideStep('Sağ ayağı yıkamak (Farz)', 'Wash the right foot (obligatory)',
        'Sağ ayak parmak aralarıyla, topukla birlikte 3 kez yıkanır.',
        'Wash the right foot up to and including the ankle, 3 times.',
        Icons.directions_walk_rounded,
        image: 'assets/images/guides/abdest/abdest_10.webp'),
    GuideStep('Sol ayağı yıkamak (Farz)', 'Wash the left foot (obligatory)',
        'Sol ayak parmak aralarıyla, topukla birlikte 3 kez yıkanır.',
        'Wash the left foot up to and including the ankle, 3 times.',
        Icons.directions_run_rounded,
        image: 'assets/images/guides/abdest/abdest_11.webp'),
    GuideStep('Dua etmek', 'Closing supplication',
        'Abdest bitince kelime-i şehadet getirilir ve abdest duası okunur.',
        'After wudu, recite the shahada and the closing supplication.',
        Icons.volunteer_activism_rounded,
        image: 'assets/images/guides/abdest/abdest_12.webp'),
  ],
  [
    GuideSection('Abdestin Farzları', 'Obligatory Acts of Wudu',
        Icons.verified_rounded, [
      'Yüzü bir kez yıkamak',
      'Kolları dirseklerle birlikte yıkamak',
      'Başın dörtte birini mesh etmek',
      'Ayakları topuklarla birlikte yıkamak',
    ], [
      'Washing the face once',
      'Washing the arms including the elbows',
      'Wiping a quarter of the head',
      'Washing the feet including the ankles',
    ]),
    GuideSection('Sık Yapılan Hatalar', 'Common Mistakes',
        Icons.error_outline_rounded, [
      'Azaları 3 kereden eksik veya fazla yıkamak',
      'Sıraya (tertibe) uymamak',
      'Suyu israf etmek',
      'Başı mesh ederken eli ıslatmamak',
      'Oje, su geçirmez makyaj veya yara bandının altına suyun ulaşmaması',
      'Acele edip parmak aralarını ve topukları ıslatmamak',
    ], [
      'Washing limbs fewer or more than 3 times',
      'Not following the proper order',
      'Wasting water',
      'Wiping the head with a dry hand',
      'Water not reaching skin under nail polish, waterproof makeup or plasters',
      'Rushing and missing between the fingers or the ankles',
    ]),
    GuideSection('Abdesti Bozan Durumlar', 'What Breaks Wudu',
        Icons.block_rounded, [
      'Önden veya arkadan bir şeyin çıkması (idrar, gaz vb.)',
      'Vücuttan akacak kadar kan veya irin çıkması',
      'Ağız dolusu kusmak',
      'Bayılmak, sarhoş olmak',
      'Namazda sesli gülmek',
      'Yatarak veya bir yere dayanarak uyumak',
    ], [
      'Anything exiting the front or back passage',
      'Flowing blood or pus from the body',
      'Vomiting a mouthful',
      'Fainting or intoxication',
      'Laughing aloud during prayer',
      'Sleeping lying down or leaning',
    ]),
    GuideSection('Kadınlar ve Erkekler İçin', 'For Women & Men',
        Icons.people_rounded, [
      'Abdestin alınışında kadın ile erkek arasında fark yoktur; adımlar aynıdır.',
      'Oje veya su geçirmez makyaj varsa abdestten önce temizlenmelidir; su mutlaka deriye ulaşmalıdır.',
      'Topuklara ve parmak aralarına suyun ulaşmasına özen gösterilmelidir.',
    ], [
      'There is no difference between men and women in performing wudu.',
      'Nail polish or waterproof makeup must be removed first so water reaches the skin.',
      'Take care that water reaches the ankles and between the fingers/toes.',
    ]),
  ],
  st: 'Kaynak: Diyanet İşleri Başkanlığı — İlmihal (Abdest bölümü); TDV İslâm Ansiklopedisi.',
  se: 'Source: Turkish Presidency of Religious Affairs (Diyanet) — Ilmihal; TDV Encyclopedia of Islam.',
);

// ── #17 Namaz Rehberi ────────────────────────────────────────────────────
const namazGuide = Guide(
  'Namaz Rehberi',
  'Prayer Guide',
  'Namaz, günde beş vakit kılınan en önemli ibadettir. Aşağıda iki rekâtlık bir namazın adımları sırasıyla anlatılmıştır.',
  'Salah is the most important act of worship, performed five times a day. Below are the steps of a two-rakat prayer.',
  Icons.self_improvement_rounded,
  [
    GuideStep('Niyet', 'Intention',
        'Kılınacak namaza kalben ve dille niyet edilir (ör. "Niyet ettim Allah rızası için sabah namazının farzını kılmaya").',
        'Make the intention for the specific prayer, in the heart and with the tongue.',
        Icons.favorite_rounded,
        image: 'assets/images/guides/namaz/namaz_01.webp'),
    GuideStep('İftitah Tekbiri', 'Opening Takbir',
        '"Allâhu Ekber" denilerek eller kaldırılır (erkekler kulak, kadınlar omuz hizasına) ve göbek/göğüs üzerinde bağlanır.',
        'Say "Allahu Akbar", raise the hands, then fold them.',
        Icons.front_hand_rounded,
        image: 'assets/images/guides/namaz/namaz_02.webp'),
    GuideStep('Kıyam', 'Standing (Qiyam)',
        'Sübhâneke, Eûzü-Besmele, Fâtiha ve bir zamm-ı sûre okunur.',
        'Recite Subhanaka, the Basmala, al-Fatiha and a short surah.',
        Icons.accessibility_new_rounded,
        image: 'assets/images/guides/namaz/namaz_03.webp'),
    GuideStep('Rükû', 'Bowing (Ruku)',
        '"Allâhu Ekber" ile eğilinir, eller dize konur ve 3 kez "Sübhâne Rabbiye\'l-Azîm" denir.',
        'Bow with "Allahu Akbar", hands on knees, and say "Subhana Rabbiyal-Azim" 3 times.',
        Icons.accessibility_rounded,
        image: 'assets/images/guides/namaz/namaz_04.webp'),
    GuideStep('Kavme', 'Rising (Qawmah)',
        '"Semiallâhü limen hamideh" diyerek doğrulup "Rabbenâ leke\'l-hamd" denir.',
        'Rise saying "Sami\'Allahu liman hamidah", then "Rabbana laka\'l-hamd".',
        Icons.straighten_rounded,
        image: 'assets/images/guides/namaz/namaz_01.webp'),
    GuideStep('Secde', 'Prostration (Sajda)',
        '"Allâhu Ekber" ile secdeye varılır, 3 kez "Sübhâne Rabbiye\'l-A\'lâ" denir.',
        'Prostrate with "Allahu Akbar" and say "Subhana Rabbiyal-A\'la" 3 times.',
        Icons.self_improvement_rounded,
        image: 'assets/images/guides/namaz/namaz_06.webp'),
    GuideStep('Celse ve İkinci Secde', 'Sitting & Second Sajda',
        'Kısa bir oturuşun (celse) ardından ikinci secdeye varılır ve aynı tesbih okunur.',
        'Sit briefly, then perform the second prostration with the same tasbih.',
        Icons.chair_rounded,
        image: 'assets/images/guides/namaz/namaz_07.webp'),
    GuideStep('İkinci Rekât', 'Second Rakat',
        'Ayağa kalkılır; Fâtiha ve zamm-ı sûre okunup rükû ve secdeler tekrarlanır.',
        'Stand up; recite al-Fatiha and a surah, then repeat ruku and the prostrations.',
        Icons.repeat_rounded,
        image: 'assets/images/guides/namaz/namaz_03.webp'),
    GuideStep('Ka\'de (Oturuş)', 'Final Sitting',
        'Son oturuşta Ettahiyyâtü, Allâhümme salli, Allâhümme bârik ve Rabbenâ duaları okunur.',
        'In the final sitting recite Tashahhud, the salawat and the closing supplications.',
        Icons.event_seat_rounded,
        image: 'assets/images/guides/namaz/namaz_09.webp'),
    GuideStep('Selam', 'Salam',
        'Önce sağa, sonra sola "Esselâmü aleyküm ve rahmetullâh" denilerek namaz tamamlanır.',
        'Turn to the right then the left saying the salam to complete the prayer.',
        Icons.waving_hand_rounded,
        image: 'assets/images/guides/namaz/namaz_10.webp'),
  ],
  [
    GuideSection('Namaza Hazırlık', 'Preparing for Prayer',
        Icons.checklist_rounded, [
      'Abdestli olmak',
      'Beden, elbise ve namaz kılınacak yerin temiz olması',
      'Avret yerlerinin örtülü olması (setr-i avret)',
      'Kıbleye yönelmek',
      'Namaz vaktinin girmiş olması ve niyet etmek',
    ], [
      'Being in a state of wudu',
      'Cleanliness of body, clothing and place',
      'Covering the body properly (awrah)',
      'Facing the qibla',
      'The prayer time having entered, and making intention',
    ]),
    GuideSection('Kadın ve Erkek Duruş Farkları', 'Posture: Women & Men',
        Icons.people_rounded, [
      'Tekbirde erkekler elleri kulak hizasına, kadınlar omuz/göğüs hizasına kaldırır.',
      'El bağlamada erkekler göbek altında, kadınlar göğüs üzerinde bağlar.',
      'Rükûda erkekler sırtını düz tutar; kadınlar daha az eğilir.',
      'Secdede erkekler kollarını yana açar; kadınlar kollarını yana ve karnına toplayarak durur.',
      'Oturuşta erkekler sol ayağı yatırır; kadınlar her iki ayağı sağa çıkararak oturur.',
    ], [
      'In takbir, men raise hands to ear level, women to the shoulders/chest.',
      'Men fold hands below the navel, women on the chest.',
      'In ruku, men keep the back straight; women bow less.',
      'In sajda, men keep arms apart; women keep them close to the body.',
      'In sitting, men lay the left foot; women sit with both feet to the right.',
    ]),
    GuideSection('Farz Namazların Rekâtları', 'Fard Prayer Rakats',
        Icons.numbers_rounded, [
      'Sabah: 2 rekât (farz)',
      'Öğle: 4 rekât (farz)',
      'İkindi: 4 rekât (farz)',
      'Akşam: 3 rekât (farz)',
      'Yatsı: 4 rekât (farz)',
      'Vitir: 3 rekât (vâcip, yatsıdan sonra kılınır)',
    ], [
      'Fajr: 2 rakats (fard)',
      'Dhuhr: 4 rakats (fard)',
      'Asr: 4 rakats (fard)',
      'Maghrib: 3 rakats (fard)',
      'Isha: 4 rakats (fard)',
      'Witr: 3 rakats (wajib, prayed after Isha)',
    ]),
    GuideSection('Sabah Namazı — 4 rekât', 'Fajr — 4 rakats',
        Icons.wb_twilight_rounded, [
      '2 rekât sünnet (önce kılınır)',
      '2 rekât farz',
    ], [
      '2 rakats sunnah (prayed first)',
      '2 rakats fard',
    ]),
    GuideSection('Öğle Namazı — 10 rekât', 'Dhuhr — 10 rakats',
        Icons.wb_sunny_rounded, [
      '4 rekât ilk sünnet',
      '4 rekât farz',
      '2 rekât son sünnet',
    ], [
      '4 rakats first sunnah',
      '4 rakats fard',
      '2 rakats final sunnah',
    ]),
    GuideSection('İkindi Namazı — 8 rekât', 'Asr — 8 rakats',
        Icons.brightness_6_rounded, [
      '4 rekât sünnet',
      '4 rekât farz',
    ], [
      '4 rakats sunnah',
      '4 rakats fard',
    ]),
    GuideSection('Akşam Namazı — 5 rekât', 'Maghrib — 5 rakats',
        Icons.nights_stay_rounded, [
      '3 rekât farz (önce kılınır)',
      '2 rekât son sünnet',
    ], [
      '3 rakats fard (prayed first)',
      '2 rakats final sunnah',
    ]),
    GuideSection('Yatsı Namazı — 13 rekât', 'Isha — 13 rakats',
        Icons.dark_mode_rounded, [
      '4 rekât ilk sünnet',
      '4 rekât farz',
      '2 rekât son sünnet',
      '3 rekât vitir (vâcip) — yatsıdan sonra kılınır',
    ], [
      '4 rakats first sunnah',
      '4 rakats fard',
      '2 rakats final sunnah',
      '3 rakats witr (wajib) — prayed after Isha',
    ]),
  ],
  st: 'Kaynak: Diyanet İşleri Başkanlığı — İlmihal (Namaz bölümü); TDV İslâm Ansiklopedisi.',
  se: 'Source: Turkish Presidency of Religious Affairs (Diyanet) — Ilmihal; TDV Encyclopedia of Islam.',
);

// ── Gusül (Boy Abdesti) ──────────────────────────────────────────────────
const gusulGuide = Guide(
  'Gusül (Boy Abdesti)',
  'Ghusl (Full Ablution)',
  'Gusül; cünüplük, hayız (âdet) ve nifas (loğusalık) hâllerinden sonra bütün vücudun yıkanmasıyla yapılan büyük temizliktir. Namaz, Kâbe\'yi tavaf ve Kur\'an\'a dokunmak için gereklidir.',
  'Ghusl is the major purification — washing the whole body — required after janabah, menstruation and post-natal bleeding, before prayer, tawaf and touching the Qur\'an.',
  Icons.shower_rounded,
  [
    GuideStep('Niyet ve Besmele', 'Intention & Basmala',
        'Gusle niyet edilip besmele çekilir.',
        'Make the intention for ghusl and say the Basmala.',
        Icons.favorite_rounded),
    GuideStep('Elleri ve avret yerini yıkamak', 'Wash hands & private parts',
        'Eller bileklere kadar yıkanır; sonra edep yerleri ve vücuttaki necaset (pislik) temizlenir.',
        'Wash the hands to the wrists, then clean the private parts and any impurity on the body.',
        Icons.wash_rounded),
    GuideStep('Abdest almak', 'Perform wudu',
        'Namaz abdesti gibi abdest alınır. Ayakların altı su içindeyse ayaklar guslün sonuna bırakılabilir.',
        'Perform a full wudu as for prayer; the feet may be left to the end.',
        Icons.water_drop_rounded),
    GuideStep('Başa ve vücuda su dökmek', 'Pour water over the body',
        'Önce başa, sonra sağ omuza, sonra sol omuza üçer kez su dökülür; vücut iyice ovularak ıslatılır.',
        'Pour water three times over the head, then the right shoulder, then the left, rubbing thoroughly.',
        Icons.shower_rounded),
    GuideStep('Kuru yer bırakmamak', 'Leave no dry spot',
        'İğne ucu kadar kuru yer kalmamalı; göbek deliği, kulak kıvrımları ve saç dipleri mutlaka ıslatılır.',
        'Not even a needle-point may stay dry; wet the navel, ear folds and roots of the hair.',
        Icons.check_circle_rounded),
    GuideStep('Ayakları yıkamak', 'Wash the feet',
        'Abdest alırken yıkanmadıysa en sonda ayaklar yıkanır.',
        'If not washed during wudu, wash the feet last.',
        Icons.directions_walk_rounded),
  ],
  [
    GuideSection('Guslün Farzları', 'Obligatory Acts of Ghusl',
        Icons.verified_rounded, [
      'Ağza su vermek (mazmaza)',
      'Burna su vermek (istinşak)',
      'Bütün bedeni bir kez yıkamak',
    ], [
      'Rinsing the mouth (madmadah)',
      'Rinsing the nose (istinshaq)',
      'Washing the entire body once',
    ]),
    GuideSection('Gusül Gerektiren Hâller', 'When Ghusl Is Required',
        Icons.info_outline_rounded, [
      'Cünüplük (cinsel ilişki veya meninin gelmesi)',
      'Hayız (âdet) kanamasının bitmesi',
      'Nifas (loğusalık) kanamasının bitmesi',
    ], [
      'Janabah (intercourse or discharge)',
      'End of menstruation (hayd)',
      'End of post-natal bleeding (nifas)',
    ]),
    GuideSection('Dikkat Edilecekler', 'Important Notes',
        Icons.priority_high_rounded, [
      'Su deriye ulaşmalı; oje, su geçirmez madde önceden temizlenmeli.',
      'Tek bir aza bile kuru kalırsa gusül tamamlanmaz.',
      'Kadının saç örgüsünü çözmesi şart değildir; saç diplerine suyun ulaşması yeterlidir.',
    ], [
      'Water must reach the skin; remove nail polish or waterproof substances first.',
      'If even one part stays dry, the ghusl is incomplete.',
      'A woman need not undo braids; wetting the roots of the hair suffices.',
    ]),
  ],
  st: 'Kaynak: Diyanet İşleri Başkanlığı — İlmihal (Gusül bölümü); TDV İslâm Ansiklopedisi.',
  se: 'Source: Diyanet — Ilmihal (Ghusl); TDV Encyclopedia of Islam.',
);

// ── Teyemmüm ─────────────────────────────────────────────────────────────
const teyemmumGuide = Guide(
  'Teyemmüm',
  'Tayammum (Dry Ablution)',
  'Teyemmüm; su bulunmadığında ya da su kullanmak hastalık gibi bir sebeple zararlı olduğunda, temiz toprak (veya toprak cinsinden bir şey) ile yapılan, abdest ve gusül yerine geçen temizliktir.',
  'Tayammum is dry purification with clean earth — a substitute for wudu and ghusl — when water is unavailable or harmful to use.',
  Icons.landscape_rounded,
  [
    GuideStep('Niyet', 'Intention',
        'Teyemmüme (abdest veya gusül yerine geçmesine) niyet edilir.',
        'Intend the tayammum (in place of wudu or ghusl).',
        Icons.favorite_rounded),
    GuideStep('Toprağa ilk vuruş', 'First strike on earth',
        'İki el temiz toprağa (toz, taş, kum, kireç) vurulur ve hafifçe silkilir.',
        'Strike both hands on clean earth (dust, stone, sand, lime) and shake lightly.',
        Icons.back_hand_rounded),
    GuideStep('Yüzü mesh etmek', 'Wipe the face',
        'Ellerin içiyle bütün yüz bir kez mesh edilir.',
        'Wipe the entire face once with the palms.',
        Icons.face_retouching_natural_rounded),
    GuideStep('Toprağa ikinci vuruş', 'Second strike on earth',
        'Eller tekrar toprağa vurulup silkelenir.',
        'Strike the hands on the earth again and shake.',
        Icons.back_hand_rounded),
    GuideStep('Kolları mesh etmek', 'Wipe the arms',
        'Önce sağ kol parmak ucundan dirsekle birlikte, sonra sol kol mesh edilir.',
        'Wipe the right arm to the elbow, then the left.',
        Icons.front_hand_rounded),
  ],
  [
    GuideSection('Teyemmümün Farzları', 'Obligatory Acts',
        Icons.verified_rounded, [
      'Niyet etmek',
      'İki darbe: yüzü ve kolları (dirseklerle) mesh etmek',
    ], [
      'Making the intention',
      'Two strikes: wiping the face and arms (to the elbows)',
    ]),
    GuideSection('Ne Zaman Câizdir?', 'When Is It Permitted?',
        Icons.help_outline_rounded, [
      'Abdest/gusül için yeterli su bulunmaması',
      'Suya ulaşamamak (hastalık, düşman, yırtıcı hayvan vb.)',
      'Su kullanmanın hastalığı artırması veya iyileşmeyi geciktirmesi',
      'Suyun, namaz vakti çıkacak kadar uzakta olması',
    ], [
      'No water available for wudu/ghusl',
      'Unable to reach water (illness, danger, etc.)',
      'Water would worsen illness or delay recovery',
      'Water so far that the prayer time would pass',
    ]),
    GuideSection('Teyemmümü Bozan Şeyler', 'What Invalidates It',
        Icons.block_rounded, [
      'Abdesti veya guslü bozan her şey',
      'Suyun bulunması ya da kullanılabilir hâle gelmesi',
    ], [
      'Anything that breaks wudu or ghusl',
      'Water becoming available or usable',
    ]),
  ],
  st: 'Kaynak: Diyanet İşleri Başkanlığı — İlmihal (Teyemmüm bölümü); TDV İslâm Ansiklopedisi.',
  se: 'Source: Diyanet — Ilmihal (Tayammum); TDV Encyclopedia of Islam.',
);

// ── Mest Üzerine Mesh ────────────────────────────────────────────────────
const mestGuide = Guide(
  'Mest Üzerine Mesh',
  'Wiping Over Khuffayn',
  'Abdestliyken giyilen mestlerin (topuğu örten, su geçirmeyen ayak giysisi) üzerine, abdest bozulduğunda ayakları yıkamak yerine ıslak elle mesh edilmesidir.',
  'When wudu breaks, instead of washing the feet one may wipe over khuffayn (leather socks) put on while in wudu.',
  Icons.ice_skating_rounded,
  [
    GuideStep('Abdestliyken giymek', 'Put on while in wudu',
        'Mestler, ayaklar yıkanıp abdest tamamlandıktan SONRA giyilmiş olmalıdır.',
        'The socks must be put on after washing the feet and completing wudu.',
        Icons.checkroom_rounded),
    GuideStep('Süreyi başlatmak', 'When the time starts',
        'Mesh süresi, mest giyildikten sonra abdestin İLK bozulduğu andan itibaren işler.',
        'The period starts from the first time wudu breaks after putting them on.',
        Icons.schedule_rounded),
    GuideStep('Eli ıslatmak', 'Wet the hand',
        'Abdest bozulunca, mesh için el ıslatılır.',
        'After wudu breaks, wet the hand for wiping.',
        Icons.water_drop_rounded),
    GuideStep('Mesh etmek', 'Wipe over the socks',
        'Islak elin parmaklarıyla, ayak parmakları ucundan bacağa doğru mest üzeri bir kez çizgi hâlinde mesh edilir (her ayak kendi eliyle).',
        'With wet fingers, draw one line over each sock from the toes toward the shin.',
        Icons.touch_app_rounded),
  ],
  [
    GuideSection('Mesh Süresi', 'Duration of Wiping',
        Icons.timer_rounded, [
      'Mukim (yolcu olmayan) için: 24 saat (1 gün 1 gece)',
      'Yolcu (seferî) için: 72 saat (3 gün 3 gece)',
    ], [
      'For a resident: 24 hours (1 day & night)',
      'For a traveller: 72 hours (3 days & nights)',
    ]),
    GuideSection('Mestin Şartları', 'Conditions of the Socks',
        Icons.rule_rounded, [
      'Abdestli giyilmiş olmalı',
      'Topukları (aşık kemiklerini) örtmeli',
      'Su geçirmemeli, sağlam olmalı',
      'Ayak parmaklarından küçük 3 parmak kadar delik/yırtık bulunmamalı',
    ], [
      'Put on while in wudu',
      'Cover the ankles',
      'Waterproof and sturdy',
      'No tear larger than three small toes',
    ]),
    GuideSection('Meshi Bozan Şeyler', 'What Ends the Wiping',
        Icons.block_rounded, [
      'Abdesti bozan her şey',
      'Mestin (birinin bile) ayaktan çıkması',
      'Mesh süresinin dolması',
      'Süre dolunca veya mest çıkınca sadece ayakları yıkayıp abdest tamamlanır.',
    ], [
      'Anything that breaks wudu',
      'Removing either sock',
      'The wiping period expiring',
      'When time ends or a sock comes off, just wash the feet to complete wudu.',
    ]),
  ],
  st: 'Kaynak: Diyanet İşleri Başkanlığı — İlmihal (Mest bölümü); TDV İslâm Ansiklopedisi.',
  se: 'Source: Diyanet — Ilmihal (Khuffayn); TDV Encyclopedia of Islam.',
);

// ── Yara / Sargı Üzerine Mesh ────────────────────────────────────────────
const sargiGuide = Guide(
  'Yara ve Sargı Üzerine Mesh',
  'Wiping Over a Dressing',
  'Yara, kırık, çıban veya alçı/sargı sebebiyle bir uzvu yıkamak ya da sargıyı açmak zararlıysa; o uzuv yerine sargının (alçının) üzerine mesh edilir.',
  'If washing a limb or removing a dressing would harm a wound, fracture or plaster, one wipes over the dressing instead.',
  Icons.healing_rounded,
  [
    GuideStep('Sağlam azaları yıkamak', 'Wash the healthy parts',
        'Abdest veya gusülde yıkanması gereken sağlam organlar normal şekilde yıkanır.',
        'Wash the healthy limbs normally as in wudu or ghusl.',
        Icons.wash_rounded),
    GuideStep('Sargıyı mesh etmek', 'Wipe over the dressing',
        'Yara/sargı/alçı bulunan uzvun yıkanacak yeri yerine, ıslak elle sargının üzeri mesh edilir.',
        'Instead of the covered area, wipe over the bandage/plaster with a wet hand.',
        Icons.touch_app_rounded),
    GuideStep('Çoğunluğunu mesh etmek', 'Wipe most of it',
        'Sargının çoğunu (yarısından fazlasını) mesh etmek yeterlidir.',
        'Wiping over most (more than half) of the dressing suffices.',
        Icons.check_circle_rounded),
  ],
  [
    GuideSection('Ne Zaman Yapılır?', 'When It Applies',
        Icons.help_outline_rounded, [
      'Yarayı yıkamak zarar verecekse',
      'Sargıyı/alçıyı açmak zarar verecek veya iyileşmeyi geciktirecekse',
    ], [
      'When washing the wound would cause harm',
      'When removing the dressing would harm or delay healing',
    ]),
    GuideSection('Önemli Notlar', 'Important Notes',
        Icons.priority_high_rounded, [
      'Sargıyı açmak zararsızsa altındaki sağlam deri yıkanır.',
      'Sargı değişse de meshi tekrarlamak gerekmez.',
      'Sargı kendiliğinden düşerse yeniden mesh edilir.',
      'Birden fazla uzuvda sargı varsa her biri için geçerlidir.',
    ], [
      'If uncovering is harmless, wash the healthy skin beneath.',
      'No need to repeat the wipe if the dressing is changed.',
      'If the dressing falls off, wipe again.',
      'It applies to each bandaged limb.',
    ]),
  ],
  st: 'Kaynak: Diyanet İşleri Başkanlığı — İlmihal; TDV İslâm Ansiklopedisi.',
  se: 'Source: Diyanet — Ilmihal; TDV Encyclopedia of Islam.',
);
