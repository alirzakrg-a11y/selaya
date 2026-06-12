import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

/// "HH:mm"
String formatClock(DateTime t) => DateFormat('HH:mm').format(t);

/// "HH:mm:ss"
String formatClockSeconds(DateTime t) => DateFormat('HH:mm:ss').format(t);

/// "HH:mm:ss" countdown from a duration.
String formatCountdown(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final neg = d.isNegative;
  final dd = d.abs();
  final s = '${two(dd.inHours)}:${two(dd.inMinutes % 60)}:${two(dd.inSeconds % 60)}';
  return neg ? '-$s' : s;
}

/// "29 Mayıs 2026" / "29 May 2026"
String formatGregorian(DateTime d, String locale) =>
    DateFormat('d MMMM yyyy', locale).format(d);

/// "Cuma" / "Friday"
String formatWeekday(DateTime d, String locale) =>
    DateFormat('EEEE', locale).format(d);

/// Hijri date with localized month names, e.g. "12 Zilhicce 1447".
/// [offsetDays] applies the user's manual Hijri-day correction (±days).
String formatHijri(DateTime d, String locale, {int offsetDays = 0}) {
  HijriCalendar.language = locale == 'tr' ? 'tr' : 'en';
  final adjusted = offsetDays == 0 ? d : d.add(Duration(days: offsetDays));
  return HijriCalendar.fromDate(adjusted).toFormat('dd MMMM yyyy');
}
