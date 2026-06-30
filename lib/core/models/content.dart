import 'package:flutter/material.dart' show Color;

import '../localization/localized_text.dart';

Map<String, dynamic> _tr(Map<String, dynamic> j) =>
    (j['translations'] as Map).cast<String, dynamic>();

Color hexColor(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

class Surah {
  final int number;
  final String arabic;
  final String transliteration;
  final int ayahCount;
  final String revelation; // meccan | medinan
  final Map<String, dynamic> translations;
  const Surah(
    this.number,
    this.arabic,
    this.transliteration,
    this.ayahCount,
    this.revelation,
    this.translations,
  );

  String name(String l) => translations.mapFor(l)['name'] as String;

  factory Surah.fromJson(Map<String, dynamic> j) => Surah(
    j['number'] as int,
    j['arabic'] as String,
    j['transliteration'] as String,
    j['ayahCount'] as int,
    j['revelation'] as String,
    _tr(j),
  );
}

class Verse {
  final int ayah;
  final String arabic;
  final String transliteration;
  final String? audio;
  final Map<String, dynamic> translations;
  const Verse(
    this.ayah,
    this.arabic,
    this.transliteration,
    this.audio,
    this.translations,
  );

  String meaning(String l) => translations.stringFor(l);

  factory Verse.fromJson(Map<String, dynamic> j) => Verse(
    j['ayah'] as int,
    j['arabic'] as String,
    j['transliteration'] as String? ?? '',
    j['audio'] as String?,
    _tr(j),
  );
}

class Asma {
  final int id;
  final int order;
  final String arabic;
  final String transliteration;
  final Map<String, dynamic> translations;
  const Asma(
    this.id,
    this.order,
    this.arabic,
    this.transliteration,
    this.translations,
  );

  String name(String l) => translations.mapFor(l)['name'] as String;
  String meaning(String l) => translations.mapFor(l)['meaning'] as String;

  factory Asma.fromJson(Map<String, dynamic> j) => Asma(
    j['id'] as int,
    j['order'] as int,
    j['arabic'] as String,
    j['transliteration'] as String,
    _tr(j),
  );
}

class Dua {
  final String id;
  final String category;
  final String source;
  final String arabic;
  final String transliteration;
  final Map<String, dynamic> translations;
  const Dua(
    this.id,
    this.category,
    this.source,
    this.arabic,
    this.transliteration,
    this.translations,
  );

  String title(String l) => translations.mapFor(l)['title'] as String;
  String text(String l) => translations.mapFor(l)['text'] as String;

  factory Dua.fromJson(Map<String, dynamic> j) => Dua(
    j['id'] as String,
    j['category'] as String,
    j['source'] as String? ?? '',
    j['arabic'] as String,
    j['transliteration'] as String? ?? '',
    _tr(j),
  );
}

class Hadith {
  final String id;
  final String collection;
  final String narrator;
  final String grade;
  final String arabic;
  final Map<String, dynamic> translations;
  const Hadith(
    this.id,
    this.collection,
    this.narrator,
    this.grade,
    this.arabic,
    this.translations,
  );

  String text(String l) => translations.mapFor(l)['text'] as String;

  factory Hadith.fromJson(Map<String, dynamic> j) => Hadith(
    j['id'] as String,
    j['collection'] as String,
    j['narrator'] as String? ?? '',
    j['grade'] as String? ?? '',
    j['arabic'] as String,
    _tr(j),
  );
}

class InspirationItem {
  final String id;
  final String type; // verse | hadith | dua
  final String reference;
  final String image;
  final String arabic;
  final Map<String, dynamic> translations;
  const InspirationItem(
    this.id,
    this.type,
    this.reference,
    this.image,
    this.arabic,
    this.translations,
  );

  String text(String l) => translations.mapFor(l)['text'] as String;

  factory InspirationItem.fromJson(Map<String, dynamic> j) => InspirationItem(
    j['id'] as String,
    j['type'] as String,
    j['reference'] as String? ?? '',
    j['image'] as String? ?? '',
    j['arabic'] as String? ?? '',
    _tr(j),
  );
}

class AudioEpisode {
  final String id;
  final String audio; // url
  final int durationSec;
  final String cover;
  final String text; // tam hikâye metni (oynatıcıda okuma için)
  final Map<String, dynamic> translations;
  const AudioEpisode(this.id, this.audio, this.durationSec, this.cover,
      this.text, this.translations);

  String title(String l) => translations.mapFor(l)['title'] as String;
  String subtitle(String l) =>
      translations.mapFor(l)['subtitle'] as String? ?? '';

  factory AudioEpisode.fromJson(Map<String, dynamic> j) => AudioEpisode(
        j['id'] as String,
        j['audio'] as String,
        j['durationSec'] as int? ?? 0,
        j['cover'] as String? ?? '',
        j['text'] as String? ?? '',
        _tr(j),
      );
}

class AudioStoryCategory {
  final String id;
  final String iconKey;
  final String accent;
  final String cover;
  final List<AudioEpisode> episodes;
  final Map<String, dynamic> translations;
  const AudioStoryCategory(this.id, this.iconKey, this.accent, this.cover,
      this.episodes, this.translations);

  String title(String l) => translations.mapFor(l)['title'] as String;
  String subtitle(String l) =>
      translations.mapFor(l)['subtitle'] as String? ?? '';
  Color get accentColor => hexColor(accent);

  factory AudioStoryCategory.fromJson(Map<String, dynamic> j) =>
      AudioStoryCategory(
        j['id'] as String,
        j['iconKey'] as String? ?? 'prophets',
        j['accent'] as String? ?? '#E0B250',
        j['cover'] as String? ?? '',
        (j['episodes'] as List)
            .map((e) =>
                AudioEpisode.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        _tr(j),
      );
}

class StorySlide {
  final String image;
  final int durationMs;
  final String? arabic;
  final String? video; // panel video hikâyesi (varsa görsel yerine oynatılır)
  final Map<String, dynamic> translations;
  const StorySlide(
    this.image,
    this.durationMs,
    this.arabic,
    this.translations, {
    this.video,
  });

  String heading(String l) =>
      translations.mapFor(l)['heading'] as String? ?? '';
  String body(String l) => translations.mapFor(l)['body'] as String? ?? '';
}

class Story {
  final String id;
  final String type;
  final String accent;
  final String cover;
  final List<StorySlide> slides;
  final Map<String, dynamic> translations;
  const Story(
    this.id,
    this.type,
    this.accent,
    this.cover,
    this.slides,
    this.translations,
  );

  String title(String l) => translations.mapFor(l)['title'] as String;
  Color get accentColor => hexColor(accent);
}

class GreetingMessage {
  final String id;
  final Map<String, dynamic> translations;
  const GreetingMessage(this.id, this.translations);

  String text(String l) => translations.mapFor(l)['text'] as String;

  factory GreetingMessage.fromJson(Map<String, dynamic> j) =>
      GreetingMessage(j['id'] as String, _tr(j));
}

class GreetingOccasion {
  final String
  occasion; // friday | bayram | ramazan | kandil | birthday | general
  final String iconKey;
  final List<GreetingMessage> messages;
  final Map<String, dynamic> translations;
  const GreetingOccasion(
    this.occasion,
    this.iconKey,
    this.messages,
    this.translations,
  );

  String label(String l) => translations.mapFor(l)['label'] as String;

  factory GreetingOccasion.fromJson(Map<String, dynamic> j) => GreetingOccasion(
    j['occasion'] as String,
    j['iconKey'] as String? ?? 'card',
    (j['messages'] as List)
        .map(
          (e) => GreetingMessage.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
    _tr(j),
  );
}

class CalendarDay {
  final String id;
  final DateTime gregorian;
  final String hijri;
  final String type;
  final int days; // duration (1 for single-day, e.g. 4 for Eid al-Adha)
  final Map<String, dynamic> translations;
  const CalendarDay(
    this.id,
    this.gregorian,
    this.hijri,
    this.type,
    this.days,
    this.translations,
  );

  String name(String l) => translations.mapFor(l)['name'] as String;
  String note(String l) => translations.mapFor(l)['note'] as String? ?? '';

  /// 1-based index of [now] within this event's span, or 0 if outside.
  /// e.g. Eid day 1, 2, 3...
  int activeDayIndex(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(gregorian.year, gregorian.month, gregorian.day);
    final diff = today.difference(start).inDays;
    return (diff >= 0 && diff < days) ? diff + 1 : 0;
  }

  bool get isMultiDay => days > 1;

  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(
    j['id'] as String,
    DateTime.parse(j['gregorian'] as String),
    j['hijri'] as String,
    j['type'] as String,
    j['days'] as int? ?? 1,
    _tr(j),
  );
}

class Wallpaper {
  final String id;
  final String category;
  final String image;
  final bool premium;
  final List<String> palette;
  final Map<String, dynamic> translations;

  /// Küçük önizleme URL'si (panel ≤560px WebP üretir); ızgaralar bunu indirir,
  /// tam boy [image] yalnızca detay/indirme ekranında çekilir.
  final String thumb;

  /// Yapay zeka ile üretilen görsel → uygulamada "Yapay zeka ile üretildi" rozeti.
  final bool ai;

  const Wallpaper(
    this.id,
    this.category,
    this.image,
    this.premium,
    this.palette,
    this.translations, {
    this.thumb = '',
    this.ai = false,
  });

  /// Izgara/kart görünümleri için: önizleme varsa o, yoksa tam görsel.
  String get gridImage => thumb.isEmpty ? image : thumb;

  String title(String l) => translations.mapFor(l)['title'] as String;
  List<Color> get colors => palette.map(hexColor).toList();
}

class Mosque {
  final String id;
  final double lat;
  final double lng;
  final double distanceKm;
  final Map<String, dynamic> translations;
  const Mosque(this.id, this.lat, this.lng, this.distanceKm, this.translations);

  String name(String l) => translations.mapFor(l)['name'] as String;
  String address(String l) =>
      translations.mapFor(l)['address'] as String? ?? '';

  factory Mosque.fromJson(Map<String, dynamic> j) => Mosque(
    j['id'] as String,
    (j['lat'] as num).toDouble(),
    (j['lng'] as num).toDouble(),
    (j['distanceKm'] as num?)?.toDouble() ?? 0,
    _tr(j),
  );
}

class FeedItem {
  final String id;
  final String type;
  final String poster;
  final String video;
  final String author;
  final int likes;
  final Map<String, dynamic> translations;
  const FeedItem(
    this.id,
    this.type,
    this.poster,
    this.video,
    this.author,
    this.likes,
    this.translations,
  );

  String title(String l) => translations.mapFor(l)['title'] as String;
  String caption(String l) =>
      translations.mapFor(l)['caption'] as String? ?? '';
}

class DhikrPreset {
  final String id;
  final String arabic;
  final String transliteration;
  final int target;
  final Map<String, dynamic> translations;
  const DhikrPreset(
    this.id,
    this.arabic,
    this.transliteration,
    this.target,
    this.translations,
  );

  String name(String l) => translations.mapFor(l)['name'] as String;
  String meaning(String l) =>
      translations.mapFor(l)['meaning'] as String? ?? '';

  factory DhikrPreset.fromJson(Map<String, dynamic> j) => DhikrPreset(
    j['id'] as String,
    j['arabic'] as String,
    j['transliteration'] as String? ?? '',
    j['target'] as int? ?? 33,
    _tr(j),
  );
}
