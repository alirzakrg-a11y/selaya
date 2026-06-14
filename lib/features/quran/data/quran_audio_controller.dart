import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'quran_download_service.dart';
import 'quran_tracks.dart';

/// Çalan sure durumu.
class QuranAudioState {
  final int? surahNumber;
  final String surahName;
  final bool playing;
  final bool loading;
  const QuranAudioState({
    this.surahNumber,
    this.surahName = '',
    this.playing = false,
    this.loading = false,
  });

  QuranAudioState copyWith({
    int? surahNumber,
    String? surahName,
    bool? playing,
    bool? loading,
    bool clear = false,
  }) =>
      QuranAudioState(
        surahNumber: clear ? null : (surahNumber ?? this.surahNumber),
        surahName: clear ? '' : (surahName ?? this.surahName),
        playing: playing ?? this.playing,
        loading: loading ?? this.loading,
      );
}

/// Kur'an/Yâsîn sesli okuması — KENDİ sade just_audio oynatıcısı.
///
/// Kullanıcı isteği (2026-06-14): player'ı baştan SADE kur. audio_service
/// KULLANILMAZ → medya BİLDİRİMİ YOK, global mini YOK, arka plan/kilit-ekranı
/// kumandası YOK. Yalnız: ÇAL / DUR. Sure bitince (son ayet tamamlanınca)
/// KENDİLİĞİNDEN DURUR — sıradaki sureye GEÇMEZ ("başka bir şey yapma"). Kumanda
/// doğrudan sure listesindeki butonda (play/stop + dolan halka). Aynı anda ya
/// Kur'an ya sesli hikâye çalar: Kur'an başlayınca hikâye durdurulur, hikâye
/// başlayınca [clearStale] ile Kur'an durur (app.dart onModeChanged bağlar).
class QuranAudioController extends Notifier<QuranAudioState> {
  final AudioPlayer _player = AudioPlayer();
  List<MediaTrack> _tracks = const [];

  @override
  QuranAudioState build() {
    final sub = _player.playerStateStream.listen((s) {
      if (state.surahNumber == null) return;
      state = state.copyWith(
        playing: s.playing,
        loading: s.processingState == ProcessingState.loading ||
            s.processingState == ProcessingState.buffering,
      );
      // Sure bitti → DUR (sıradaki sureye geçme — sade play/stop). just_audio
      // 'completed'da playing=true bıraktığından temizlemezsek buton "çalıyor"
      // gibi takılı kalır; stop() state'i sıfırlar → buton "play"e döner.
      if (s.processingState == ProcessingState.completed) stop();
    });
    ref.onDispose(sub.cancel);
    ref.onDispose(_player.dispose);
    return const QuranAudioState();
  }

  List<MediaTrack> get tracks => _tracks;
  String get art => _tracks.isNotEmpty ? _tracks.first.artUri : '';
  bool get isQuranMode => state.surahNumber != null;
  int get currentIndex => _player.currentIndex ?? 0;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  /// İlerleme — THROTTLE'LI (200ms = 5fps). just_audio'nun varsayılan
  /// `positionStream`'i kısa ayet parçalarında ~16ms'de bir tetikleyip okuyucu/
  /// liste halkasını sürekli yeniden çizerek donmaya yol açıyordu.
  Stream<Duration> get positionStream => _player.createPositionStream(
        steps: 200,
        minPeriod: const Duration(milliseconds: 200),
        maxPeriod: const Duration(milliseconds: 200),
      );
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Bu sure ŞU AN çalıyor mu (liste butonu için).
  bool isPlayingSurah(int surahNumber) =>
      state.surahNumber == surahNumber && state.playing;

  /// Çalan parçanın AYET numarası (`<sure>_<ayet>` kimliğinden) — okuyucu vurgusu
  /// için. Çözülemezse null.
  int? get currentAyahNumber {
    final i = _player.currentIndex;
    if (i == null || i < 0 || i >= _tracks.length) return null;
    final p = _tracks[i].id.split('_');
    return p.length >= 2 ? int.tryParse(p.last) : null;
  }

  /// Sureyi (ayet parça listesi) [index]'ten çalar. Çalan sesli hikâye varsa
  /// durdurur (tek ses kuralı).
  Future<void> play(int surahNumber, String surahName, List<MediaTrack> tracks,
      int index) async {
    if (tracks.isEmpty) return;
    // Sure İNDİRİLMİŞSE yerel dosyalardan çal (offline, veri/akış yok); değilse
    // CDN url'leri. İndirme servisi çözer.
    final resolved = ref
        .read(quranDownloadProvider.notifier)
        .resolveTracks(surahNumber, tracks);
    _tracks = resolved;
    state = state.copyWith(
        surahNumber: surahNumber,
        surahName: surahName,
        loading: true,
        playing: true);
    // DÜZ AKIŞ (AudioSource.uri) — kanıtlanmış yol; Kur'an ses proxy'si range
    // istemediğinden LockCaching denenip geri alınmıştı (bazı cihazlarda susuyor).
    final sources = [
      for (final t in resolved) AudioSource.uri(Uri.parse(t.url))
    ];
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await _player.setAudioSources(sources,
          initialIndex: index.clamp(0, tracks.length - 1));
      await _player.play();
    } catch (_) {}
  }

  Future<void> toggle() async =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> stop() async {
    _tracks = const [];
    await _player.stop();
    state = const QuranAudioState();
  }

  Future<void> seek(Duration pos) => _player.seek(pos);
  Future<void> jumpTo(int index) => _player.seek(Duration.zero, index: index);

  /// ⏭ Sıradaki ayet (sure içinde). Son ayette no-op (sure sonunda durur).
  Future<void> next() async {
    final i = _player.currentIndex ?? 0;
    if (i < _tracks.length - 1) await _player.seekToNext();
  }

  /// ⏮ Önceki ayet (sure içinde). İlk ayette başa sarar.
  Future<void> previous() async {
    final i = _player.currentIndex ?? 0;
    if (i > 0) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  /// Sesli hikâye çalmaya başlayınca (app.dart onModeChanged) Kur'an'ı durdurup
  /// bayat durumu temizler — player'a değil kendi sesimize dokunur.
  void clearStale() {
    if (state.surahNumber != null || state.playing || state.loading) {
      _tracks = const [];
      _player.stop();
      state = const QuranAudioState();
    }
  }
}

final quranAudioControllerProvider =
    NotifierProvider<QuranAudioController, QuranAudioState>(
        QuranAudioController.new);
