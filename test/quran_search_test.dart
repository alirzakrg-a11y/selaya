import 'package:flutter_test/flutter_test.dart';
import 'package:selaya/core/models/content.dart';
import 'package:selaya/features/quran/presentation/quran_search_screen.dart';

// --- Fixtures (gerçek modeller, gömülü çift dilli çeviri formatıyla) ---
Surah _surah(int n, String name, String translit, {int ayahCount = 7}) => Surah(
      n,
      'سورة',
      translit,
      ayahCount,
      'meccan',
      {
        'tr': {'name': name},
        'en': {'name': name},
      },
    );

Verse _verse(int ayah, String meaning,
        {String arabic = '', String translit = ''}) =>
    Verse(ayah, arabic, translit, null, {'tr': meaning, 'en': meaning});

void main() {
  final surahs = [
    _surah(1, 'Fâtiha', 'Al-Fatiha'),
    _surah(2, 'Bakara', 'Al-Baqarah', ayahCount: 286),
    _surah(112, 'İhlâs', 'Al-Ikhlas'),
  ];

  final index = <(int, Verse)>[
    (1, _verse(1, 'Rahmân ve Rahîm olan Allah\'ın adıyla',
        arabic: 'بِسْمِ اللَّهِ', translit: 'Bismillah')),
    (2, _verse(153, 'Ey iman edenler! Sabır ve namaz ile yardım isteyin.',
        translit: 'Ya ayyuhalladhina')),
    (2, _verse(155, 'Sizi biraz korku ve açlıkla deneriz; sabır gösterenleri müjdele.')),
    (112, _verse(1, 'De ki: O Allah birdir.', arabic: 'قل هو الله أحد')),
  ];

  group('quranSearch', () {
    test('2 karakterden kısa / boş sorgu boş döner', () {
      expect(quranSearch('s', 'tr', surahs, index).isEmpty, isTrue);
      expect(quranSearch('', 'tr', surahs, index).isEmpty, isTrue);
    });

    test('meal kelimesiyle ayet bulur (sabır → 2 ayet, ikisi de Bakara)', () {
      final r = quranSearch('sabır', 'tr', surahs, index);
      expect(r.verses.length, 2);
      expect(r.verses.every((e) => e.$1 == 2), isTrue);
      expect(r.surahs, isEmpty);
    });

    test('sure adıyla sure bulur (bakara)', () {
      final r = quranSearch('bakara', 'tr', surahs, index);
      expect(r.surahs.length, 1);
      expect(r.surahs.first.number, 2);
    });

    test('okunuş (transliteration) ile bulur (bismillah)', () {
      final r = quranSearch('bismillah', 'tr', surahs, index);
      expect(r.verses.any((e) => e.$1 == 1 && e.$2.ayah == 1), isTrue);
    });

    test('Arapça metinle bulur (الله → yalnız harekesiz İhlâs)', () {
      final r = quranSearch('الله', 'tr', surahs, index);
      expect(r.verses.length, 1);
      expect(r.verses.first.$1, 112);
    });

    test('büyük/küçük harf duyarsız', () {
      expect(quranSearch('BAKARA', 'tr', surahs, index).surahs.length, 1);
      expect(quranSearch('Sabır', 'tr', surahs, index).verses.length, 2);
    });

    test('eşleşme yoksa boş', () {
      expect(quranSearch('xyzzy', 'tr', surahs, index).isEmpty, isTrue);
    });

    test('cap ayet sonucunu sınırlar + capped işaretler', () {
      final many = <(int, Verse)>[
        for (var i = 1; i <= 10; i++) (2, _verse(i, 'sabır tekrar $i')),
      ];
      final r = quranSearch('sabır', 'tr', surahs, many, cap: 4);
      expect(r.verses.length, 4);
      expect(r.capped, isTrue);
    });
  });

  group('searchSnippet', () {
    test('kısa metni olduğu gibi bırakır', () {
      expect(searchSnippet('Sabır güzeldir', 'sabır'), 'Sabır güzeldir');
    });

    test('uzun metinde eşleşme derinse pencere alır (… ön ek)', () {
      final long = '${'a' * 90} sabır sonrası gelen huzur';
      final snip = searchSnippet(long, 'sabır');
      expect(snip.startsWith('…'), isTrue);
      expect(snip.toLowerCase().contains('sabır'), isTrue);
      expect(snip.length, lessThan(long.length));
    });

    test('boş sorgu metni değiştirmez', () {
      expect(searchSnippet('herhangi metin', ''), 'herhangi metin');
    });
  });
}
