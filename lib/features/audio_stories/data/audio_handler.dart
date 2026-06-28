import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Set in main() when `AudioService.init` fails — then the background media
/// notification is unavailable (playback falls back to a plain player).
String? audioServiceError;

/// Tek bir çalınabilir parça (sesli hikâye bölümü). Handler'ın içerik modeline
/// bağımlı kalmaması için başlık/kapak önceden çözülmüş halde verilir.
class MediaTrack {
  final String id;
  final String url;
  final String title;
  final String artUri; // kapak (CDN url) — bildirim/kilit ekranı görseli
  final int durationSec;
  const MediaTrack({
    required this.id,
    required this.url,
    required this.title,
    this.artUri = '',
    this.durationSec = 0,
  });
}

// ─── Kur'an sesi YEREL CACHE (kullanıcı 2026-06-15) ──────────────────────────
// İlk dinleyişte her ayet mp3'ü telefona kaydedilir; sonraki dinleyişler YEREL
// dosyadan çalar → 0 ağ / 0 veri / 0 Cloudflare isteği. everyayah proxy'si HTTP
// range desteklemediğinden LockCachingAudioSource yerine basit "tam dosya indir".
Directory? _quranAudioCacheDir;
Future<Directory> _quranAudioDir() async {
  final cached = _quranAudioCacheDir;
  if (cached != null) return cached;
  final base = await getApplicationSupportDirectory();
  final d = Directory('${base.path}/quran_audio');
  if (!await d.exists()) await d.create(recursive: true);
  return _quranAudioCacheDir = d;
}

File _quranCacheFile(Directory dir, MediaTrack t) =>
    File('${dir.path}/${t.id.replaceAll(RegExp(r'[^0-9A-Za-z_]'), '_')}.mp3');

/// Çalma listesini çözer: yereli olan ayet dosyadan (ağ YOK), olmayan ağdan akar.
Future<List<AudioSource>> _resolveQuranSources(List<MediaTrack> list) async {
  final dir = await _quranAudioDir();
  return Future.wait(
    list.map((t) async {
      final f = _quranCacheFile(dir, t);
      if (await f.exists() && await f.length() > 1024) {
        return AudioSource.uri(Uri.file(f.path));
      }
      return AudioSource.uri(Uri.parse(t.url));
    }),
  );
}

/// Kur'an ayet sesi ŞU AN arka planda İNDİRİLİYOR mu — UI çok küçük, ibadeti
/// BÖLMEYEN bir "indiriliyor" rozeti göstersin diye (kullanıcı 2026-06-17). Aynı
/// anda birden çok ayet inebileceğinden sayaçla yönetilir: hepsi bitince false.
final ValueNotifier<bool> quranCaching = ValueNotifier<bool>(false);
int _activeQuranDownloads = 0;
Timer? _quranCachingHideTimer;

/// Tek ayeti (çalarken) arka planda indirir — yalnız henüz yoksa. Tek-tek
/// indirildiğinden toplu istek patlaması (thundering herd) olmaz; rate-limit'i
/// de zorlamaz. İndirme başlayınca [quranCaching] true olur; son indirme bitince
/// kısa bir gecikmeyle (rozet görünür kalsın diye) false olur.
Future<void> _cacheQuranTrack(MediaTrack t) async {
  try {
    final dir = await _quranAudioDir();
    final f = _quranCacheFile(dir, t);
    if (await f.exists() && await f.length() > 1024) return; // zaten yerel
    _activeQuranDownloads++;
    _quranCachingHideTimer?.cancel(); // yeni indirme → bekleyen gizlemeyi iptal
    quranCaching.value = true;
    try {
      final resp = await http.get(Uri.parse(t.url));
      if (resp.statusCode == 200 && resp.bodyBytes.length > 1024) {
        await f.writeAsBytes(resp.bodyBytes, flush: true);
      }
    } finally {
      if (--_activeQuranDownloads <= 0) {
        _activeQuranDownloads = 0;
        // Hızlı internette indirme ANINDA biter → rozet göz açıp kapayana kadar
        // kaybolmasın: son indirmeden ~1.8 sn sonra gizle. Yeni indirme gelirse
        // yukarıdaki cancel ile ertelenir. (kullanıcı 2026-06-17)
        _quranCachingHideTimer?.cancel();
        _quranCachingHideTimer = Timer(const Duration(milliseconds: 1800), () {
          if (_activeQuranDownloads <= 0) quranCaching.value = false;
        });
      }
    }
  } catch (_) {}
}

/// true = bu surenin TÜM ayet sesleri telefonda cache'li → çevrimdışı çalar.
/// (UI'ın "internet yok, indirilmemiş" bilgisi vermesi için — kullanıcı 2026-06-15.)
Future<bool> quranTracksCached(List<MediaTrack> list) async {
  if (list.isEmpty) return false;
  final dir = await _quranAudioDir();
  for (final t in list) {
    final f = _quranCacheFile(dir, t);
    if (!await f.exists() || await f.length() <= 1024) return false;
  }
  return true;
}

// ─── Sesli hikâye YEREL CACHE — Kur'an ile AYNI mantık (kullanıcı isteği:
// "ses başlatılınca indirilsin, uygulama kasmasın"). İlk dinleyiş ağdan akar +
// arka planda telefona kaydedilir; sonraki dinleyiş yerelden (0 ağ/veri). ─────
Directory? _storyAudioCacheDir;
Future<Directory> _storyAudioDir() async {
  final cached = _storyAudioCacheDir;
  if (cached != null) return cached;
  final base = await getApplicationSupportDirectory();
  final d = Directory('${base.path}/story_audio');
  if (!await d.exists()) await d.create(recursive: true);
  return _storyAudioCacheDir = d;
}

File _storyCacheFile(Directory dir, MediaTrack t) =>
    File('${dir.path}/${t.id.replaceAll(RegExp(r'[^0-9A-Za-z_]'), '_')}.mp3');

Future<List<AudioSource>> _resolveStorySources(List<MediaTrack> list) async {
  final dir = await _storyAudioDir();
  return Future.wait(
    list.map((t) async {
      final f = _storyCacheFile(dir, t);
      if (await f.exists() && await f.length() > 1024) {
        return AudioSource.uri(Uri.file(f.path));
      }
      return AudioSource.uri(Uri.parse(t.url));
    }),
  );
}

/// Sesli hikâye ŞU AN arka planda İNDİRİLİYOR mu — küçük "indiriliyor" rozeti için.
final ValueNotifier<bool> storyCaching = ValueNotifier<bool>(false);
int _activeStoryDownloads = 0;
Timer? _storyCachingHideTimer;

Future<void> _cacheStoryTrack(MediaTrack t) async {
  try {
    final dir = await _storyAudioDir();
    final f = _storyCacheFile(dir, t);
    if (await f.exists() && await f.length() > 1024) return; // zaten yerel
    _activeStoryDownloads++;
    _storyCachingHideTimer?.cancel();
    storyCaching.value = true;
    try {
      final resp = await http.get(Uri.parse(t.url));
      if (resp.statusCode == 200 && resp.bodyBytes.length > 1024) {
        await f.writeAsBytes(resp.bodyBytes, flush: true);
      }
    } finally {
      if (--_activeStoryDownloads <= 0) {
        _activeStoryDownloads = 0;
        _storyCachingHideTimer?.cancel();
        _storyCachingHideTimer = Timer(const Duration(milliseconds: 1800), () {
          if (_activeStoryDownloads <= 0) storyCaching.value = false;
        });
      }
    }
  } catch (_) {}
}

/// true = bu bölüm sesi telefonda cache'li (çevrimdışı çalar).
Future<bool> storyTrackCached(MediaTrack t) async {
  final dir = await _storyAudioDir();
  final f = _storyCacheFile(dir, t);
  return await f.exists() && await f.length() > 1024;
}

/// audio_service handler — bir sesli-hikâye çalma listesini (bölümler) arka
/// planda oynatır ve medya bildirimini (kilit ekranı / YouTube-Music tarzı
/// kumanda) yönetir. Tek paylaşılan player.
class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();

  /// 'story' (bölüm listesi çalıyor) | 'idle' (boşta).
  String mode = 'idle';
  List<MediaTrack> tracks = const [];
  String album = '';

  static const _procMap = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };

  AppAudioHandler() {
    player.playerStateStream.listen((_) => _broadcast());
    player.playbackEventStream.listen((_) => _broadcast());
    // Bölüm değişince bildirimdeki başlık/kapak güncellensin.
    player.currentIndexStream.listen((i) {
      _setTrackMediaItem(i);
      // Çalan parçayı arka planda telefona indir → sonraki dinleyiş yerelden
      // (0 ağ/veri). Kur'an + sesli hikâye modlarında.
      if (i != null && i >= 0 && i < tracks.length) {
        if (mode == 'quran') {
          unawaited(_cacheQuranTrack(tracks[i]));
        } else if (mode == 'story') {
          unawaited(_cacheStoryTrack(tracks[i]));
        }
      }
    });
  }

  void _broadcast() {
    final playing = player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _procMap[player.processingState]!,
        playing: playing,
      ),
    );
  }

  @override
  Future<void> skipToNext() => player.seekToNext();

  @override
  Future<void> skipToPrevious() => player.seekToPrevious();

  /// Tekrar düğmesi: tek bölümü döngüye al / kapat.
  Future<void> setLoop(bool one) =>
      player.setLoopMode(one ? LoopMode.one : LoopMode.off);

  /// Sesli hikâye: bölüm listesi (prev/next bölümler arasında gezer).
  Future<void> playPlaylist(
    List<MediaTrack> list, {
    String albumTitle = '',
    int startIndex = 0,
    String mode = 'story',
  }) async {
    if (list.isEmpty) return;
    this.mode = mode;
    tracks = list;
    album = albumTitle;
    final idx = startIndex.clamp(0, list.length - 1);
    // Sesli hikâye: ÇALMADAN ÖNCE başlangıç bölümünü indir → yerelden çalar
    // (streaming donması olmaz). storyCaching rozeti "indiriliyor" gösterir.
    if (mode == 'story') await _cacheStoryTrack(list[idx]);
    // Kur'an modunda YEREL CACHE: kaydedilmiş ayet dosyadan (ağ YOK), olmayan
    // ağdan akar + çalarken arka planda indirilir → SONRAKİ dinleyiş 0 ağ/veri/
    // Cloudflare isteği. (Hikâye/diğer modlar düz akış.) LockCachingAudioSource
    // değil — everyayah proxy range desteklemiyor; bu yüzden "tam dosya indir".
    final sources = mode == 'quran'
        ? await _resolveQuranSources(list)
        : mode == 'story'
            ? await _resolveStorySources(list)
            : [for (final t in list) AudioSource.uri(Uri.parse(t.url))];
    try {
      // Medyayı her zaman MEDYA akışında çal — alarm ezanı oturumu alarm akışına
      // almış olabilir; burada geri medyaya çekiyoruz (Kuran/sesli hikâye sesi).
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await player.setAudioSources(sources, initialIndex: idx);
      _setTrackMediaItem(idx);
      await player.play();
    } catch (_) {}
  }

  void _setTrackMediaItem(int? i) {
    if (i == null || i < 0 || i >= tracks.length) return;
    final t = tracks[i];
    mediaItem.add(
      MediaItem(
        id: t.id,
        title: t.title,
        album: album.isNotEmpty ? album : 'Sesli Hikâye',
        artist: 'SELAYA',
        artUri: t.artUri.isNotEmpty ? Uri.tryParse(t.artUri) : null,
        duration: t.durationSec > 0 ? Duration(seconds: t.durationSec) : null,
      ),
    );
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    tracks = const [];
    mode = 'idle';
    mediaItem.add(null);
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }
}

/// The app-wide media handler. Overridden in `main()` with the
/// `AudioService.init` result; falls back to a plain handler if init fails.
final audioHandlerProvider = Provider<AppAudioHandler>(
  (ref) => throw UnimplementedError('overridden in main()'),
);
