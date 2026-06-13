import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

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

/// audio_service handler — bir sesli-hikâye çalma listesini (bölümler) arka
/// planda oynatır ve medya bildirimini (kilit ekranı / YouTube-Music tarzı
/// kumanda) yönetir. Tek paylaşılan player.
class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();

  /// 'story' (bölüm listesi çalıyor) | 'quran' | 'idle' (boşta).
  String mode = 'idle';
  List<MediaTrack> tracks = const [];
  String album = '';

  /// Mode değişiminin TEK bildirim noktası (app.dart bağlar): yeni kaynak
  /// çalmaya başlayınca / tamamen durunca önceki modun controller'ı bayat
  /// durumunu temizler. Salt bildirim — çalma mantığına etkisi yok.
  void Function(String newMode)? onModeChanged;

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
    player.currentIndexStream.listen(_setTrackMediaItem);
    // Parça YÜKLENİNCE gerçek süreyi bildirime yaz → bildirim ilerleme çubuğu
    // çalışsın. Kur'an/Yâsîn parçalarının durationSec'i 0 (CDN sesi); süre
    // yalnız oynatıcı yükleyince bilinir, bu yüzden burada güncelleniyor.
    player.durationStream.listen((d) {
      final m = mediaItem.value;
      if (m != null && d != null && d > Duration.zero && m.duration != d) {
        mediaItem.add(m.copyWith(duration: d));
      }
    });
  }

  void _broadcast() {
    final playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 3],
      processingState: _procMap[player.processingState]!,
      playing: playing,
      // KONUM bildir → bildirim ilerleme çubuğu hareket etsin (eskiden yoktu
      // → çubuk pasif kalıyordu). audio_service bunlar arasında interpolasyon
      // yapar; her playbackEvent'te güncellenmesi yeterli.
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    ));
  }

  @override
  Future<void> skipToNext() => player.seekToNext();

  @override
  Future<void> skipToPrevious() => player.seekToPrevious();

  /// Sesli hikâye: bölüm listesi (prev/next bölümler arasında gezer).
  Future<void> playPlaylist(List<MediaTrack> list,
      {String albumTitle = '', int startIndex = 0, String mode = 'story'}) async {
    if (list.isEmpty) return;
    final prevMode = this.mode;
    this.mode = mode;
    tracks = list;
    album = albumTitle;
    if (prevMode != mode) onModeChanged?.call(mode);
    final idx = startIndex.clamp(0, list.length - 1);
    // DÜZ AKIŞ (AudioSource.uri) — kanıtlanmış yol. LockCachingAudioSource
    // DENENDİ ve GERİ ALINDI: Kur'an ses proxy'miz (api.selaya.app) range
    // isteklerini desteklemediğinden bazı cihazlarda sesi tamamen susturuyordu.
    // Veri tasarrufu zaten sunucu tarafında (edge 30 gün önbellek) sağlanıyor.
    final sources = [for (final t in list) AudioSource.uri(Uri.parse(t.url))];
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
    mediaItem.add(MediaItem(
      id: t.id,
      title: t.title,
      album: album.isNotEmpty ? album : 'Sesli Hikâye',
      artist: 'SELAYA',
      artUri: t.artUri.isNotEmpty ? Uri.tryParse(t.artUri) : null,
      duration: t.durationSec > 0 ? Duration(seconds: t.durationSec) : null,
    ));
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    tracks = const [];
    final prevMode = mode;
    mode = 'idle';
    mediaItem.add(null);
    playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle, playing: false));
    // Bildirimden gelen Durdur dahil her duruşta haber ver → controller'lar
    // bayat durum bırakmasın.
    if (prevMode != 'idle') onModeChanged?.call('idle');
  }
}

/// The app-wide media handler. Overridden in `main()` with the
/// `AudioService.init` result; falls back to a plain handler if init fails.
final audioHandlerProvider = Provider<AppAudioHandler>(
    (ref) => throw UnimplementedError('overridden in main()'));
