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
  final locale = ref.watch(appLocaleProvider);
  final out = <Dua>[];
  final seen = <String>{};
  Dua? fromPanel(ContentItem c) {
    final text = (c.title ?? '').trim();
    if (text.isEmpty) return null;
    final ex = c.extra ?? const <String, dynamic>{};
    final source = (c.subtitle ?? '').trim();
    final name = source.isEmpty ? 'Dua' : source;
    // Çoklu-dil: extra.langs[locale].title = çevrilmiş metin (yoksa TR). dedup TR ile.
    final loc = ((ex['langs'] as Map?)?[locale] as Map?)?.cast<String, dynamic>();
    final lt = (loc?['title'] as String?)?.trim();
    final disp = (lt != null && lt.isNotEmpty) ? lt : text;
    return Dua(c.id, 'panel', source, (ex['arabic'] ?? '').toString(), '', {
      locale: {'title': name, 'text': disp},
      'tr': {'title': name, 'text': text},
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
  final locale = ref.watch(appLocaleProvider);
  final out = <Hadith>[];
  final seen = <String>{};
  for (final c in ref.watch(collectionProvider('hadiths'))) {
    final t = c.title ?? '';
    if (t.isEmpty) continue;
    seen.add(t.trim());
    final r = (c.extra?['reference'] ?? '').toString();
    final loc = ((c.extra?['langs'] as Map?)?[locale] as Map?)?.cast<String, dynamic>();
    final lt = (loc?['title'] as String?)?.trim();
    final disp = (lt != null && lt.isNotEmpty) ? lt : t;
    out.add(
      Hadith(c.id, r, r, '', (c.extra?['arabic'] ?? '').toString(), {
        locale: {'text': disp},
        'tr': {'text': t},
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
  final locale = ref.watch(appLocaleProvider);
  final out = <InspirationItem>[];
  final seen = <String>{};
  for (final c in ref.watch(collectionProvider('inspiration'))) {
    final t = c.title ?? '';
    if (t.isEmpty && c.url.isEmpty) continue;
    seen.add(t.trim());
    final ex = c.extra ?? const <String, dynamic>{};
    final loc = ((ex['langs'] as Map?)?[locale] as Map?)?.cast<String, dynamic>();
    final lt = (loc?['title'] as String?)?.trim();
    final disp = (lt != null && lt.isNotEmpty) ? lt : t;
    out.add(
      InspirationItem(
        c.id,
        (ex['type'] ?? 'verse').toString(),
        (ex['reference'] ?? c.subtitle ?? '').toString(),
        c.url,
        (ex['arabic'] ?? '').toString(),
        {
          locale: {'text': disp},
          'tr': {'text': t},
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

/// Panelde eklenen hikâyeler (görsel VEYA video). ÇOKLU-DİL: resim/video ORTAK,
/// başlık/metin dile göre `extra.langs[locale]`'den gelir (yoksa TR = title/subtitle).
/// Tek kayıt + içine diller → panelde 9 ayrı eklemek gerekmez; dil değişince
/// metin değişir, görsel aynı kalır. Eski tek-dilli kayıtlar bozulmadan TR gösterir.
final storiesProvider = FutureProvider<List<Story>>((ref) async {
  // Hikâyeler TEK kayıt + extra.langs (gömülü çeviri) modeli → satır-bazlı dil
  // SÜZMESİ YAPMA (ofLang değil .of); hepsini al, metin extra.langs[locale]'den.
  final extras =
      ref.watch(manifestProvider).value?.of('stories') ?? const <ContentItem>[];
  final locale = ref.watch(appLocaleProvider);
  final out = <Story>[];
  for (final c in extras) {
    if (c.url.isEmpty) continue;
    // extra.langs[locale] varsa o dilin metni; yoksa TR yedeği (title/subtitle).
    final langs = (c.extra?['langs'] as Map?)?.cast<String, dynamic>();
    final loc = (langs?[locale] as Map?)?.cast<String, dynamic>();
    // BUG fix (tarama): '?? ' yalnızca null'ı yutar; BOŞ string'i de "eksik" sayıp
    // TR'ye düşmeliyiz — yarım çeviride (başlık boş) boş başlık görünmesin.
    final lt = (loc?['title'] as String?)?.trim();
    final ls = (loc?['subtitle'] as String?)?.trim();
    final ct = (c.title ?? '').trim();
    final cs = (c.subtitle ?? '').trim();
    final t =
        (lt != null && lt.isNotEmpty) ? lt : (ct.isNotEmpty ? ct : 'Hikâye');
    final sub = (ls != null && ls.isNotEmpty) ? ls : cs;
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
            // Çözümlenmiş (locale'e göre) metni hem aktif dile hem TR'ye koy →
            // görüntüleyici hangi anahtara bakarsa baksın doğru metni bulur.
            {
              locale: {'heading': t, 'body': sub},
              'tr': {'heading': t, 'body': sub},
            },
            video: isVideo ? c.url : null,
          ),
        ],
        {
          locale: {'title': t},
          'tr': {'title': t},
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

/// Panelde mevcut duvar kâğıtları — ÇOKLU-DİL: görsel ORTAK, başlık dile göre
/// extra.langs[locale]'den (yoksa TR=title). Hikâyelerle aynı model (.of, satır
/// süzmesi yok). Not: wallpaper subtitle 'custom' bayrağı, çeviri yalnız başlığa.
final wallpapersProvider = FutureProvider<List<Wallpaper>>((ref) async {
  final extras =
      ref.watch(manifestProvider).value?.of('wallpapers') ?? const <ContentItem>[];
  final locale = ref.watch(appLocaleProvider);
  final out = <Wallpaper>[];
  for (final c in extras) {
    if (c.url.isEmpty) continue;
    final langs = (c.extra?['langs'] as Map?)?.cast<String, dynamic>();
    final loc = (langs?[locale] as Map?)?.cast<String, dynamic>();
    final lt = (loc?['title'] as String?)?.trim();
    final ct = (c.title ?? '').trim();
    final t = (lt != null && lt.isNotEmpty) ? lt : ct;
    out.add(
      Wallpaper(
        c.id,
        (c.subtitle?.trim().isNotEmpty ?? false) ? c.subtitle!.trim() : 'custom',
        c.url,
        false,
        const ['#05070D', '#E0B250'],
        {
          locale: {'title': t},
          'tr': {'title': t},
        },
        thumb: c.thumb ?? '',
        ai: c.extra?['ai'] == true,
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

/// Panelden eklenen reel'ler (video, CDN'den oynar) — ÇOKLU-DİL: video ORTAK,
/// başlık + caption dile göre extra.langs[locale]'den (yoksa TR). Hikâye modeli.
final feedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final extras =
      ref.watch(manifestProvider).value?.of('feed') ?? const <ContentItem>[];
  final locale = ref.watch(appLocaleProvider);
  final out = <FeedItem>[];
  for (final c in extras) {
    if (c.url.isEmpty) continue;
    final langs = (c.extra?['langs'] as Map?)?.cast<String, dynamic>();
    final loc = (langs?[locale] as Map?)?.cast<String, dynamic>();
    final lt = (loc?['title'] as String?)?.trim();
    final ls = (loc?['subtitle'] as String?)?.trim();
    final t = (lt != null && lt.isNotEmpty) ? lt : (c.title ?? '').trim();
    // Caption (SELAYA'nın altında görünen açıklama) = extra.langs.subtitle / TR subtitle.
    final cap = (ls != null && ls.isNotEmpty) ? ls : (c.subtitle ?? '').trim();
    out.add(
      FeedItem(c.id, 'video', c.thumb ?? '', c.url, 'SELAYA', 0, {
        locale: {'title': t, 'caption': cap},
        'tr': {'title': t, 'caption': cap},
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

/// Panelden eklenen sesli hikâye kategorileri (audio_stories). Her panel öğesi
/// kendi kapağı/başlığı + extra.episodes[] ile bir [AudioStoryCategory] olur.
/// İçerik TR (özellik diğer dillerde gizli; bkz. ekran/giriş kapısı).
final audioStoriesProvider =
    FutureProvider<List<AudioStoryCategory>>((ref) async {
  final extras = ref.watch(collectionProvider('audio_stories'));
  final cats = <AudioStoryCategory>[];
  for (final c in extras) {
    final eps = (c.extra?['episodes'] as List?) ?? const [];
    if (c.url.isEmpty || eps.isEmpty) continue;
    final cover = c.url;
    final t = c.title ?? 'Sesli Hikâye';
    final sub = c.subtitle ?? '';
    final iconKey = (c.extra?['iconKey'] ?? 'prophets').toString();
    final accent = (c.extra?['accent'] ?? '#E0B250').toString();
    final episodes = <AudioEpisode>[];
    for (var i = 0; i < eps.length; i++) {
      final e = eps[i];
      if (e is! Map) continue;
      final audioUrl = (e['audio'] ?? '').toString();
      if (audioUrl.isEmpty) continue;
      final et = (e['title'] ?? 'Bölüm ${i + 1}').toString();
      final esub = (e['subtitle'] ?? '').toString();
      final edur =
          (e['durationSec'] is num) ? (e['durationSec'] as num).toInt() : 0;
      final ecover = (e['cover'] ?? '').toString();
      final etext = (e['text'] ?? '').toString();
      episodes.add(AudioEpisode('${c.id}_$i', audioUrl, edur,
          ecover.isNotEmpty ? ecover : cover, etext, {
        'tr': {'title': et, 'subtitle': esub},
        'en': {'title': et, 'subtitle': esub},
      }));
    }
    if (episodes.isEmpty) continue;
    cats.insert(
      0,
      AudioStoryCategory(c.id, iconKey, accent, cover, episodes, {
        'tr': {'title': t, 'subtitle': sub},
        'en': {'title': t, 'subtitle': sub},
      }),
    );
  }
  return cats;
});

final greetingTemplatesProvider = FutureProvider<List<GreetingOccasion>>((
  ref,
) async {
  // Tebrikler tamamen paket-içi (greeting_templates.json — 10 dil gömülü).
  // Panel yönetimi kaldırıldı (kullanıcı isteği); yalnız bundled.
  return ref
      .watch(assetJsonLoaderProvider)
      .loadModels('$_data/greeting_templates.json', GreetingOccasion.fromJson);
});
