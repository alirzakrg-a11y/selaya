import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/content.dart';
import 'asset_json_loader.dart';
import 'manifest_service.dart';

const _data = 'assets/data';

final surahsProvider = FutureProvider<List<Surah>>(
  (ref) => ref
      .watch(assetJsonLoaderProvider)
      .loadModels('$_data/quran/surahs.json', Surah.fromJson),
);

/// Verses for a surah; returns empty list if the surah isn't in the demo set.
final versesProvider = FutureProvider.family<List<Verse>, int>((
  ref,
  surahNumber,
) async {
  final path =
      '$_data/quran/verses_${surahNumber.toString().padLeft(3, '0')}.json';
  try {
    return await ref
        .watch(assetJsonLoaderProvider)
        .loadModels(path, Verse.fromJson);
  } catch (_) {
    return const <Verse>[];
  }
});

final asmaProvider = FutureProvider<List<Asma>>(
  (ref) => ref
      .watch(assetJsonLoaderProvider)
      .loadModels('$_data/asma_ul_husna.json', Asma.fromJson),
);

/// Dualar: paket-içi duas.json + PANELDEN eklenenler. ⑯ Panel duaları artık
/// kendi 'duas' koleksiyonuna yazıyor; eski kayıtlar 'inspiration'a type=dua
/// olarak düşmüştü (Günün İlhamı karışıklığı) — onlar da burada okunur ki
/// hiçbir panel duası kaybolmasın. Tekrarlar metne göre ayıklanır.
final duasProvider = FutureProvider<List<Dua>>((ref) async {
  final bundled = await ref
      .watch(assetJsonLoaderProvider)
      .loadModels('$_data/duas.json', Dua.fromJson);
  final out = <Dua>[];
  final seen = <String>{};
  Dua? fromPanel(ContentItem c) {
    final text = (c.title ?? '').trim();
    if (text.isEmpty) return null;
    final ex = c.extra ?? const <String, dynamic>{};
    final source = (c.subtitle ?? '').trim();
    final name = source.isEmpty ? 'Dua' : source;
    return Dua(c.id, 'panel', source, (ex['arabic'] ?? '').toString(), '', {
      'tr': {'title': name, 'text': text},
      'en': {'title': name, 'text': text},
    });
  }

  for (final c in ref.watch(collectionProvider('duas'))) {
    final d = fromPanel(c);
    if (d == null) continue;
    seen.add(d.text('tr').trim());
    out.add(d);
  }
  for (final c in ref.watch(collectionProvider('inspiration'))) {
    if (((c.extra?['type']) ?? '').toString() != 'dua') continue;
    final d = fromPanel(c);
    if (d == null || seen.contains(d.text('tr').trim())) continue;
    seen.add(d.text('tr').trim());
    out.add(d);
  }
  for (final b in bundled) {
    if (seen.contains(b.text('tr').trim())) continue;
    out.add(b);
  }
  return out;
});

final hadithsProvider = FutureProvider<List<Hadith>>((ref) async {
  final bundled = await ref
      .watch(assetJsonLoaderProvider)
      .loadModels('$_data/hadiths.json', Hadith.fromJson);
  // Panel/API hadisleri ÖNCE; paket-içi yalnızca API'de AYNI metin yoksa
  // (taşınan içerik tekrarlanmasın). API boşsa paket-içi tam liste (offline).
  final out = <Hadith>[];
  final seen = <String>{};
  for (final c in ref.watch(collectionProvider('hadiths'))) {
    final t = c.title ?? '';
    if (t.isEmpty) continue;
    seen.add(t.trim());
    final r = (c.extra?['reference'] ?? '').toString();
    out.add(
      Hadith(c.id, r, r, '', (c.extra?['arabic'] ?? '').toString(), {
        'tr': {'text': t},
        'en': {'text': t},
      }),
    );
  }
  for (final b in bundled) {
    if (seen.contains(b.text('tr').trim())) continue;
    out.add(b);
  }
  return out;
});

/// Günün ayeti/hadisi/duası: paketteki gömülü liste (offline, daima dolu) +
/// panelden eklenenler (varsa en başa). Panel boş olsa bile içerik gelir.
final inspirationProvider = FutureProvider<List<InspirationItem>>((ref) async {
  final bundled = await ref
      .watch(assetJsonLoaderProvider)
      .loadModels('$_data/daily_inspiration.json', InspirationItem.fromJson);
  // Panel/API içeriği ÖNCE; paket-içi yalnızca API'de AYNI metin yoksa (taşınan
  // ayet/dua tekrarlanmasın). API boşsa paket-içi tam liste (offline yedek).
  final out = <InspirationItem>[];
  final seen = <String>{};
  for (final c in ref.watch(collectionProvider('inspiration'))) {
    final t = c.title ?? '';
    if (t.isEmpty && c.url.isEmpty) continue;
    seen.add(t.trim());
    final ex = c.extra ?? const <String, dynamic>{};
    out.add(
      InspirationItem(
        c.id,
        (ex['type'] ?? 'verse').toString(),
        (ex['reference'] ?? c.subtitle ?? '').toString(),
        c.url,
        (ex['arabic'] ?? '').toString(),
        {
          'tr': {'text': t},
          'en': {'text': t},
        },
      ),
    );
  }
  for (final b in bundled) {
    if (seen.contains(b.text('tr').trim())) continue;
    out.add(b);
  }
  return out;
});

/// A per-launch random seed so the home "Günün İlhamı" card shows a different
/// item each time the app is opened (it used a day index → identical all day).
/// Cached for the session, so it stays stable while browsing and only rerolls
/// on the next cold launch.
final inspirationSeedProvider = Provider<int>(
  (ref) => Random().nextInt(1 << 30),
);

/// Sadece panelde mevcut hikâyeler (görsel VEYA video).
final storiesProvider = FutureProvider<List<Story>>((ref) async {
  final extras = ref.watch(collectionProvider('stories'));
  final out = <Story>[];
  for (final c in extras) {
    if (c.url.isEmpty) continue;
    final t = c.title ?? 'Hikâye';
    final sub = c.subtitle ?? '';
    final isVideo = c.kind == 'video';
    final poster = c.thumb ?? '';
    out.add(
      Story(
        c.id,
        'special',
        '#E0B250',
        isVideo ? poster : c.url,
        [
          StorySlide(
            isVideo ? poster : c.url,
            isVideo ? 20000 : 6000,
            null,
            {
              'tr': {'heading': t, 'body': sub},
              'en': {'heading': t, 'body': sub},
            },
            video: isVideo ? c.url : null,
          ),
        ],
        {
          'tr': {'title': t},
          'en': {'title': t},
        },
      ),
    );
  }
  return out;
});

final calendarDaysProvider = FutureProvider<List<CalendarDay>>(
  (ref) => ref
      .watch(assetJsonLoaderProvider)
      .loadModels('$_data/calendar_days.json', CalendarDay.fromJson),
);

/// Today's active religious day (with its 1-based day index), or null.
final activeReligiousDayProvider =
    FutureProvider<({CalendarDay day, int index})?>((ref) async {
      final days = await ref.watch(calendarDaysProvider.future);
      final now = DateTime.now();
      for (final d in days) {
        final idx = d.activeDayIndex(now);
        if (idx > 0) return (day: d, index: idx);
      }
      return null;
    });

/// Sadece panelde mevcut duvar kâğıtları.
final wallpapersProvider = FutureProvider<List<Wallpaper>>((ref) async {
  final extras = ref.watch(collectionProvider('wallpapers'));
  final out = <Wallpaper>[];
  for (final c in extras) {
    if (c.url.isEmpty) continue;
    final t = c.title ?? '';
    out.add(
      Wallpaper(
        c.id,
        (c.subtitle?.isNotEmpty ?? false) ? c.subtitle! : 'custom',
        c.url,
        false,
        const ['#05070D', '#E0B250'],
        {
          'tr': {'title': t},
          'en': {'title': t},
        },
        thumb: c.thumb ?? '',
      ),
    );
  }
  return out;
});

final mosquesProvider = FutureProvider<List<Mosque>>(
  (ref) => ref
      .watch(assetJsonLoaderProvider)
      .loadModels('$_data/mosques.json', Mosque.fromJson),
);

/// Sadece panelden eklenen reel'ler (video, CDN'den oynar).
final feedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final extras = ref.watch(collectionProvider('feed'));
  final out = <FeedItem>[];
  for (final c in extras) {
    if (c.url.isEmpty) continue;
    final t = c.title ?? '';
    // Caption (SELAYA'nın altında görünen açıklama) = panel altyazısı (subtitle).
    final cap = c.subtitle ?? '';
    out.add(
      FeedItem(c.id, 'video', c.thumb ?? '', c.url, 'SELAYA', 0, {
        'tr': {'title': t, 'caption': cap},
        'en': {'title': t, 'caption': cap},
      }),
    );
  }
  return out;
});

final dhikrPresetsProvider = FutureProvider<List<DhikrPreset>>(
  (ref) => ref
      .watch(assetJsonLoaderProvider)
      .loadModels('$_data/dhikr_presets.json', DhikrPreset.fromJson),
);

final greetingTemplatesProvider = FutureProvider<List<GreetingOccasion>>((
  ref,
) async {
  final bundled = await ref
      .watch(assetJsonLoaderProvider)
      .loadModels('$_data/greeting_templates.json', GreetingOccasion.fromJson);
  // Panel'den eklenen tebrik mesajlarını ('greeting_msg', extra.occasion) ilgili
  // vesileye ekle → panelden ekle/çıkar yapılabilir.
  final extras = ref.watch(collectionProvider('greeting_msg'));
  if (extras.isEmpty) return bundled;
  // Panel mesajları ÖNCE; aynı metin pakette de varsa bir kez göster (panele
  // taşınınca çiftlenmesin). Panel boşsa paket yedeği döner (offline güvence).
  final seen = <String>{};
  final byOcc = <String, List<GreetingMessage>>{};
  for (final c in extras) {
    final t = (c.title ?? '').trim();
    if (t.isEmpty) continue;
    final occ = (c.extra?['occasion'] ?? 'general').toString();
    seen.add('$occ|$t');
    (byOcc[occ] ??= []).add(
      GreetingMessage(c.id, {
        'tr': {'text': t},
        'en': {'text': t},
      }),
    );
  }
  return [
    for (final o in bundled)
      GreetingOccasion(o.occasion, o.iconKey, [
        ...(byOcc[o.occasion] ?? const <GreetingMessage>[]),
        for (final m in o.messages)
          if (!seen.contains('${o.occasion}|${m.text('tr').trim()}')) m,
      ], o.translations),
  ];
});
