import 'package:flutter/services.dart';

/// Türkçe binlik ayraçlı CANLI sayı girişi biçimlendirici (1.234.567,89).
/// Kullanıcı yazarken tam sayı kısmına nokta-binlik ekler; ondalık kısım için
/// virgül kullanılır (en fazla 2 hane). İmleç metin sonuna alınır (sayı alanı).
///
/// Ayrıştırma için: `text.replaceAll('.', '').replaceAll(',', '.')` → double.
class TrThousandsFormatter extends TextInputFormatter {
  const TrThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    if (raw.isEmpty) return newValue;

    final commaIndex = raw.indexOf(',');
    final hasComma = commaIndex >= 0;
    String intDigits;
    String decDigits = '';
    if (hasComma) {
      intDigits = raw.substring(0, commaIndex).replaceAll(RegExp(r'[^0-9]'), '');
      decDigits = raw.substring(commaIndex + 1).replaceAll(RegExp(r'[^0-9]'), '');
      if (decDigits.length > 2) decDigits = decDigits.substring(0, 2);
    } else {
      intDigits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    }
    // Baştaki gereksiz sıfırları temizle ("007" → "7"), tek "0" kalabilir.
    intDigits = intDigits.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    final grouped = _group(intDigits);
    var out = grouped.isEmpty ? (hasComma ? '0' : '') : grouped;
    if (hasComma) out += ',$decDigits';

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }

  String _group(String digits) {
    if (digits.isEmpty) return '';
    final b = StringBuffer();
    final n = digits.length;
    for (var i = 0; i < n; i++) {
      if (i > 0 && (n - i) % 3 == 0) b.write('.');
      b.write(digits[i]);
    }
    return b.toString();
  }
}

/// Türkçe biçimli metni (1.234,56) double'a çevirir.
double parseTrNumber(String text) {
  final s = text.replaceAll('.', '').replaceAll(',', '.').trim();
  return double.tryParse(s) ?? 0;
}
