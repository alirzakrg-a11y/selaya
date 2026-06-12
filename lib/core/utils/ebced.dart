/// Abjad (ebced) numerology values for the Arabic letters.
const _abjad = <String, int>{
  'ا': 1, 'أ': 1, 'إ': 1, 'آ': 1, 'ٱ': 1, 'ء': 1,
  'ب': 2, 'ج': 3, 'د': 4, 'ه': 5, 'ة': 5,
  'و': 6, 'ؤ': 6, 'ز': 7, 'ح': 8, 'ط': 9,
  'ي': 10, 'ى': 10, 'ئ': 10, 'ك': 20, 'ل': 30,
  'م': 40, 'ن': 50, 'س': 60, 'ع': 70, 'ف': 80,
  'ص': 90, 'ق': 100, 'ر': 200, 'ش': 300, 'ت': 400,
  'ث': 500, 'خ': 600, 'ذ': 700, 'ض': 800, 'ظ': 900, 'غ': 1000,
};

/// Strips Arabic diacritics (harakat, tanwin, superscript alef) and tatweel.
final _diacritics = RegExp(r'[ؐ-ًؚ-ٰٟـۖ-ۭ]');

/// Computes the ebced (Abjad) value of an Arabic string. Diacritics are ignored
/// and a leading definite article "ال" is stripped — the traditional basis for
/// the recommended zikir count of the 99 names (e.g. الرحمن → رحمن → 298).
int ebcedValue(String arabic, {bool stripAl = true}) {
  var s = arabic.replaceAll(_diacritics, '').trim();
  if (stripAl && s.startsWith('ال')) s = s.substring(2);
  var total = 0;
  for (final ch in s.split('')) {
    total += _abjad[ch] ?? 0;
  }
  return total;
}
