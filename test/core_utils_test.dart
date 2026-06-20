import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selaya/core/utils/ebced.dart';
import 'package:selaya/core/utils/thousands_formatter.dart';

// Formatlayıcıyı "sıfırdan yazılmış" gibi uygula → çıktı metnini döndür.
String _fmt(String input) {
  const f = TrThousandsFormatter();
  return f
      .formatEditUpdate(
        const TextEditingValue(text: ''),
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: input.length),
        ),
      )
      .text;
}

void main() {
  group('parseTrNumber (Zekât finansal giriş)', () {
    test('binlik + ondalık', () {
      expect(parseTrNumber('1.234,56'), 1234.56);
      expect(parseTrNumber('1.234.567,89'), 1234567.89);
    });
    test('sadece binlik', () => expect(parseTrNumber('1.000'), 1000));
    test('sadece ondalık', () => expect(parseTrNumber('12,5'), 12.5));
    test('boş / geçersiz → 0', () {
      expect(parseTrNumber(''), 0);
      expect(parseTrNumber('abc'), 0);
    });
    test('sıfır', () => expect(parseTrNumber('0'), 0));
  });

  group('TrThousandsFormatter (canlı yazım)', () {
    test('binlik ayraç ekler', () {
      expect(_fmt('1234'), '1.234');
      expect(_fmt('1234567'), '1.234.567');
    });
    test('ondalık virgül korunur', () => expect(_fmt('1234,5'), '1.234,5'));
    test('ondalık en fazla 2 hane', () => expect(_fmt('1234,567'), '1.234,56'));
    test('baştaki sıfırlar temizlenir', () => expect(_fmt('007'), '7'));
    test('virgülle başlarsa 0 eklenir', () => expect(_fmt(',5'), '0,5'));
    test('boş metin boş kalır', () => expect(_fmt(''), ''));
    test('round-trip: formatla → ayrıştır aynı değer', () {
      expect(parseTrNumber(_fmt('1234567')), 1234567);
      expect(parseTrNumber(_fmt('999999,99')), 999999.99);
    });
  });

  group('ebcedValue (Esmaül Hüsna zikir sayısı)', () {
    test('الرحمن → 298 (ال atılır → رحمن)', () {
      expect(ebcedValue('الرحمن'), 298);
    });
    test('ال atmadan الرحمن → 329', () {
      expect(ebcedValue('الرحمن', stripAl: false), 329);
    });
    test('الله → 66 (geleneksel, ال atmadan)', () {
      expect(ebcedValue('الله', stripAl: false), 66);
    });
    test('tek harfler (ebced değer tablosu)', () {
      expect(ebcedValue('ب'), 2);
      expect(ebcedValue('غ'), 1000); // en yüksek harf
      expect(ebcedValue('ر'), 200);
    });
    test('hareke/bilinmeyen karakter 0 katkı', () {
      expect(ebcedValue('بَ'), 2); // ba + fetha
    });
    test('boş → 0', () => expect(ebcedValue(''), 0));
  });
}
