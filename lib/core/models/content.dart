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

  factory StorySlide.fromJson(Map<String, dynamic> j) => StorySlide(
    j['image'] as String,
    j['durationMs'] as int? ?? 6000,
    j['arabic'] as String?,
    _tr(j),
    video: j['video'] as String?,
  );
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

  factory Story.fromJson(Map<String, dynamic> j) => Story(
    j['id'] as String,
    j['type'] as String,
    j['accent'] as String? ?? '#E0B250',
    j['cover'] as String,
    (j['slides'] as List)
        .map((e) => StorySlide.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    _tr(j),
  );
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

class AiSource {
  final String type; // quran | hadith | diyanet
  final String ref;
  const AiSource(this.type, this.ref);
  factory AiSource.fromJson(Map<String, dynamic> j) =>
      AiSource(j['type'] as String, j['ref'] as String);
}

class AiQa {
  final String id;
  final String category;
  final List<AiSource> sources;
  final List<String> keywords;
  final Map<String, dynamic> translations;
  const AiQa(
    this.id,
    this.category,
    this.sources,
    this.keywords,
    this.translations,
  );

  String question(String l) => translations.mapFor(l)['question'] as String;
  String answer(String l) => translations.mapFor(l)['answer'] as String;

  factory AiQa.fromJson(Map<String, dynamic> j) => AiQa(
    j['id'] as String,
    j['category'] as String? ?? 'general',
    ((j['sources'] as List?) ?? const [])
        .map((e) => AiSource.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    ((j['keywords'] as List?) ?? const []).map((e) => e.toString()).toList(),
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

  const Wallpaper(
    this.id,
    this.category,
    this.image,
    this.premium,
    this.palette,
    this.translations, {
    this.thumb = '',
  });

  /// Izgara/kart görünümleri için: önizleme varsa o, yoksa tam görsel.
  String get gridImage => thumb.isEmpty ? image : thumb;

  String title(String l) => translations.mapFor(l)['title'] as String;
  List<Color> get colors => palette.map(hexColor).toList();

  factory Wallpaper.fromJson(Map<String, dynamic> j) => Wallpaper(
    j['id'] as String,
    j['category'] as String,
    j['image'] as String,
    j['premium'] as bool? ?? false,
    ((j['palette'] as List?) ?? const ['#05070D', '#E0B250']).cast<String>(),
    _tr(j),
  );
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

  /// Asset path today (e.g. `assets/images/videolar/x.mp4`) or a remote URL
  /// later (`https://…`); empty when the item carries no video.
  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
    j['id'] as String,
    j['type'] as String? ?? 'video',
    j['poster'] as String,
    j['video'] as String? ?? '',
    j['author'] as String? ?? 'SELAYA',
    j['likes'] as int? ?? 0,
    _tr(j),
  );
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
