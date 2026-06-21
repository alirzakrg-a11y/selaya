import 'package:flutter/material.dart';

/// Seferîlik (yolculuk) hükümleri — Hanefî mezhebi / Diyanet İşleri Başkanlığı
/// esas alınarak hazırlanmıştır. Tereddüt hâlinde bir din görevlisine danışınız.
class TravelRule {
  final IconData icon;
  final String titleTr, titleEn;
  final String descTr, descEn;
  const TravelRule(
      this.icon, this.titleTr, this.titleEn, this.descTr, this.descEn);
  String title(String l) => l == 'tr' ? titleTr : titleEn;
  String desc(String l) => l == 'tr' ? descTr : descEn;
}

const travelRules = <TravelRule>[
  TravelRule(
    Icons.route_rounded,
    'Ne zaman seferî olunur?',
    'When do you become a traveler?',
    'İkamet ettiği yerin sınırını, yaklaşık 90 km (üç günlük yürüme / 18 fersah) '
        've daha uzak bir yere, orada 15 günden az kalma niyetiyle geçen kişi '
        'seferî (yolcu) sayılır.',
    'You become a traveler (musafir) once you pass the edge of your town toward a '
        'place about 90 km or farther, intending to stay there fewer than 15 days.',
  ),
  TravelRule(
    Icons.self_improvement_rounded,
    'Namaz nasıl kılınır? (kasr)',
    'How to pray (qasr)',
    'Dört rekâtlı farzlar (öğle, ikindi, yatsı) iki rekât olarak kılınır (kasr). '
        'Sabah ve akşamın farzları değişmez. Yolda iken dört rekâtlıların sünnetleri '
        'terk edilebilir; sabahın sünneti ise kılınır.',
    'The four-rakat obligatory prayers (Dhuhr, Asr, Isha) are shortened to two '
        'rakats (qasr). Fajr and Maghrib are unchanged. While travelling the sunnahs '
        'of the four-rakat prayers may be omitted; the Fajr sunnah is kept.',
  ),
  TravelRule(
    Icons.bedtime_rounded,
    'Vitir namazı',
    'Witr prayer',
    'Vitir namazı seferde kısalmaz; her zaman olduğu gibi üç rekât kılınır '
        '(Hanefî mezhebinde vâciptir).',
    'The Witr prayer is not shortened while travelling; it is prayed as three '
        'rakats as usual (it is wajib in the Hanafi school).',
  ),
  TravelRule(
    Icons.layers_rounded,
    'Cem (birleştirme)',
    'Combining (jam‘)',
    'Hanefî mezhebine göre Arafat ve Müzdelife dışında namazlar vakitleri '
        'birleştirilerek kılınmaz. Zaruret hâlinde, Diyanet seferde namazların cem '
        'edilmesine cevaz vermektedir.',
    'In the Hanafi school prayers are not combined except at Arafat and Muzdalifah. '
        'In case of necessity, Diyanet permits combining prayers while travelling.',
  ),
  TravelRule(
    Icons.front_hand_rounded,
    'Mest üzerine mesh',
    'Wiping over socks (masah)',
    'Yolcu, abdestte mestleri üzerine 3 gün (72 saat) mesh edebilir. Mukim (yolcu '
        'olmayan) için bu süre 1 gündür (24 saat).',
    'A traveler may wipe over leather socks for 3 days (72 hours) in wudu, versus '
        '1 day (24 hours) for a resident.',
  ),
  TravelRule(
    Icons.no_food_rounded,
    'Oruç',
    'Fasting',
    'Yolcu Ramazan orucunu tutmayıp sonra kaza edebilir. Güç yetiriyor ve '
        'zorlanmıyorsa tutması daha faziletlidir.',
    'A traveler may postpone the Ramadan fast and make it up later. If able and not '
        'in hardship, fasting is more virtuous.',
  ),
  TravelRule(
    Icons.groups_rounded,
    'Cuma & bayram namazı',
    'Friday & Eid prayers',
    'Yolcuya cuma ve bayram namazı farz/vâcip değildir; dilerse kılabilir ve '
        'kıldığında sahih olur. Cuma namazını kılan kişi ayrıca o günün öğle '
        'namazını kılmaz.',
    'Friday and Eid prayers are not obligatory for a traveler; he may pray them and '
        'they are valid if he does. One who prays Friday does not also pray that '
        'day’s Dhuhr.',
  ),
  TravelRule(
    Icons.home_rounded,
    'Ne zaman mukimliğe dönülür?',
    'When do you become a resident again?',
    'Bir (aynı) yerde 15 gün veya daha fazla kalmaya niyet eden kişi mukim olur ve '
        'namazlarını tam kılar (süreyi iki ayrı yere bölmeye niyet eden seferî '
        'kalır). Ayrıca kişi vatan-ı aslîsine (doğduğu, evlendiği veya yerleşmeye '
        'karar verdiği yer) dönünce de mukim olur.',
    'Intending to stay 15 days or more in ONE place makes you a resident again, '
        'praying in full (splitting the time between two places keeps you a '
        'traveler). You also become a resident upon returning to your home town '
        '(where you were born, married, or settled).',
  ),
  TravelRule(
    Icons.history_rounded,
    'Kaza namazları',
    'Missed (qada) prayers',
    'Namaz, kaçırıldığı hâl üzere kaza edilir: seferde kaçan dört rekâtlı bir farz, '
        'sonradan mukimken bile iki rekât kaza edilir; mukimken kaçan ise seferde de '
        'dört rekât olarak kaza edilir.',
    'A prayer is made up as it was missed: a four-rakat fard missed while travelling '
        'is made up as two rakats even later at home; one missed while resident is '
        'made up as four rakats even while travelling.',
  ),
];
