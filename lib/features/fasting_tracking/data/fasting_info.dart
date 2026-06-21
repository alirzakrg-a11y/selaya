import 'package:flutter/material.dart';

// Oruç günleri bilgisi — Diyanet İşleri Başkanlığı çizgisinde, Sünnî/Hanefî.

class FastDayGroup {
  final IconData icon;
  final String titleTr, titleEn;
  final List<List<String>> items; // her madde: [tr, en]
  final bool forbidden; // yasak günler → kırmızı vurgu
  const FastDayGroup(this.icon, this.titleTr, this.titleEn, this.items,
      {this.forbidden = false});
  String title(String l) => l == 'tr' ? titleTr : titleEn;
}

const fastingGroups = <FastDayGroup>[
  FastDayGroup(
    Icons.star_rounded,
    'Sünnet (faziletli) oruçlar',
    'Recommended (sunnah) fasts',
    [
      ['Pazartesi ve Perşembe günleri', 'Mondays and Thursdays'],
      [
        'Eyyâm-ı bîd: her kamerî ayın 13, 14 ve 15. günleri',
        'Ayyam al-bid: the 13th, 14th and 15th of each lunar month'
      ],
      [
        'Aşure günü (10 Muharrem), bir gün öncesi (Tâsûâ) ile birlikte',
        'Ashura (10 Muharram), together with the day before (Tasua)'
      ],
      [
        'Arefe günü (9 Zilhicce) — hac yapmayanlar için',
        'The Day of Arafah (9 Dhul-Hijjah), for non-pilgrims'
      ],
      [
        'Şevval ayından altı gün (Ramazan’dan sonra)',
        'Six days of Shawwal, after Ramadan'
      ],
      [
        'Zilhicce’nin ilk dokuz günü',
        'The first nine days of Dhul-Hijjah'
      ],
    ],
  ),
  FastDayGroup(
    Icons.block_rounded,
    'Oruç tutmanın yasak (tahrîmen mekruh) olduğu günler',
    'Days on which fasting is forbidden',
    [
      ['Ramazan Bayramı’nın 1. günü', 'The first day of Eid al-Fitr'],
      [
        'Kurban Bayramı’nın dört günü (bayram günü + teşrik günleri)',
        'The four days of Eid al-Adha (the Eid day and the days of tashriq)'
      ],
    ],
    forbidden: true,
  ),
];

/// Kısa mekruh notu (sünnet/yasak listelerinin altında).
const fastingMekruhTr =
    'Yalnızca Cuma veya yalnızca Cumartesi günü oruç tutmak ve hiç ara vermeden sürekli (savm-ı visâl) oruç tutmak mekruhtur.';
const fastingMekruhEn =
    'Fasting only on Friday or only on Saturday, or fasting continuously without any break, is disliked (makruh).';
