import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../core/models/content.dart';

const _hijriMonthsTr = [
  'Muharrem', 'Safer', 'Rebiülevvel', 'Rebiülahir', 'Cemaziyelevvel',
  'Cemaziyelahir', 'Recep', 'Şaban', 'Ramazan', 'Şevval', 'Zilkade', 'Zilhicce'
];

class _Occ {
  final int hMonth;
  final int hDay;
  final int days;
  final String type;
  final String nameTr;
  final String nameEn;
  final String noteTr;
  final String noteEn;
  const _Occ(this.hMonth, this.hDay, this.days, this.type, this.nameTr,
      this.nameEn, this.noteTr, this.noteEn);
}

// Occasions with fixed Hijri dates — converted to Gregorian at runtime, so the
// dates stay correct for any year without hand-maintained tables.
const _occasions = [
  _Occ(1, 1, 1, 'new_year', 'Hicri Yılbaşı', 'Islamic New Year',
      'Yeni hicri yılın ilk günü.', 'First day of the new Hijri year.'),
  _Occ(1, 10, 1, 'fast', 'Aşure Günü', 'Day of Ashura',
      'Muharrem ayının 10. günü.', 'The 10th day of Muharram.'),
  _Occ(3, 12, 1, 'kandil', 'Mevlid Kandili', 'Mawlid an-Nabi',
      'Peygamberimizin doğum gecesi.', "The Prophet's birth night."),
  _Occ(7, 27, 1, 'kandil', 'Miraç Kandili', 'Laylat al-Miraj',
      'Miraç mucizesinin gecesi.', 'The night of the ascension.'),
  _Occ(8, 15, 1, 'kandil', 'Berat Kandili', "Laylat al-Bara'at",
      'Beraat ve af gecesi.', 'The night of forgiveness.'),
  _Occ(9, 1, 1, 'fast', 'Ramazan Başlangıcı', 'Start of Ramadan',
      'Oruç ayının ilk günü.', 'First day of the fasting month.'),
  _Occ(9, 27, 1, 'kandil', 'Kadir Gecesi', 'Laylat al-Qadr',
      'Bin aydan hayırlı gece.', 'The night better than a thousand months.'),
  _Occ(10, 1, 3, 'holiday', 'Ramazan Bayramı', 'Eid al-Fitr',
      '3 gün sürer.', 'Lasts 3 days.'),
  _Occ(12, 9, 1, 'fast', 'Arefe Günü', 'Day of Arafah',
      'Kurban Bayramı arifesi; oruç ve dua günü.',
      'The eve of Eid al-Adha; a day of fasting and prayer.'),
  _Occ(12, 10, 4, 'holiday', 'Kurban Bayramı', 'Eid al-Adha',
      '4 gün sürer.', 'Lasts 4 days.'),
];

/// Generates religious days for the given Hijri years, computing each Gregorian
/// date from its fixed Hijri date.
List<CalendarDay> generateReligiousDays(List<int> hijriYears) {
  final out = <CalendarDay>[];
  final cal = HijriCalendar();
  for (final hy in hijriYears) {
    for (final o in _occasions) {
      // Çok günlü bayramlar GÜN GÜN açılır: "Ramazan Bayramı 2. Günü" vb. —
      // takvimde bayramın tamamı ve kaç gün sürdüğü görünür.
      for (var d = 0; d < o.days; d++) {
        final g = cal.hijriToGregorian(hy, o.hMonth, o.hDay + d);
        final nameTr =
            o.days == 1 ? o.nameTr : '${o.nameTr} ${d + 1}. Günü';
        final nameEn =
            o.days == 1 ? o.nameEn : '${o.nameEn} — Day ${d + 1}';
        final noteTr = o.days == 1
            ? o.noteTr
            : 'Bayramın ${d + 1}. günü (${o.days} günden). ${o.noteTr}';
        final noteEn = o.days == 1
            ? o.noteEn
            : 'Day ${d + 1} of ${o.days}. ${o.noteEn}';
        out.add(CalendarDay(
          '${o.type}_${o.hMonth}_${o.hDay + d}_$hy',
          DateTime(g.year, g.month, g.day),
          '${o.hDay + d} ${_hijriMonthsTr[o.hMonth - 1]} $hy',
          o.type,
          o.days,
          {
            'tr': {'name': nameTr, 'note': noteTr},
            'en': {'name': nameEn, 'note': noteEn},
          },
        ));
      }
    }
    // Ramazan Bayramı Arifesi — Ramazan'ın SON günü (29 mu 30 mu yıla göre
    // değişir) = Şevval 1'in bir gün öncesi; hicri günü sabit olmadığından
    // gregoryen tarihten geri gidilerek bulunur.
    final fitr1 = cal.hijriToGregorian(hy, 10, 1);
    final fitrEve =
        DateTime(fitr1.year, fitr1.month, fitr1.day).subtract(const Duration(days: 1));
    out.add(CalendarDay(
      'fast_fitr_eve_$hy',
      fitrEve,
      'Ramazan $hy',
      'fast',
      1,
      {
        'tr': {
          'name': 'Arefe (Ramazan Bayramı)',
          'note': 'Ramazan Bayramı arifesi; Ramazan\'ın son günü.',
        },
        'en': {
          'name': 'Eve of Eid al-Fitr',
          'note': 'The last day of Ramadan, eve of the Eid.',
        },
      },
    ));
    // Regaib Kandili — Recep ayının (7) ilk Cuma gecesi. Sabit Hicri gün değil;
    // Recep 1'den sonraki ilk Cuma bulunur, kandil onun arifesidir (Perşembe).
    final rajab1 = cal.hijriToGregorian(hy, 7, 1);
    var fri = DateTime(rajab1.year, rajab1.month, rajab1.day);
    while (fri.weekday != DateTime.friday) {
      fri = fri.add(const Duration(days: 1));
    }
    final regaib = fri.subtract(const Duration(days: 1));
    out.add(CalendarDay(
      'kandil_regaib_$hy',
      regaib,
      'Receb $hy',
      'kandil',
      1,
      {
        'tr': {
          'name': 'Regaib Kandili',
          'note': 'Üç ayların ilk kandili; Recep\'in ilk Cuma gecesi.',
        },
        'en': {
          'name': 'Laylat al-Raghaib',
          'note': 'The first blessed night of the three holy months.',
        },
      },
    ));
  }
  out.sort((a, b) => a.gregorian.compareTo(b.gregorian));
  return out;
}

/// All religious days spanning roughly the previous, current and next Gregorian
/// years (derived from the current Hijri year).
final religiousDaysProvider = Provider<List<CalendarDay>>((ref) {
  final hyNow = HijriCalendar.now().hYear;
  return generateReligiousDays([hyNow - 1, hyNow, hyNow + 1, hyNow + 2]);
});
