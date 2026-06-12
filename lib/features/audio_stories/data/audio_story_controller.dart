import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/models/content.dart';
import 'audio_handler.dart';

/// Çalan sesli hikâye (albüm) durumu.
class AudioStoryState {
  final AudioStoryCategory? current;
  final bool playing;
  final bool loading;
  const AudioStoryState(
      {this.current, this.playing = false, this.loading = false});

  AudioStoryState copyWith({
    AudioStoryCategory? current,
    bool? playing,
    bool? loading,
    bool clear = false,
  }) =>
      AudioStoryState(
        current: clear ? null : (current ?? this.current),
        playing: playing ?? this.playing,
        loading: loading ?? this.loading,
      );
}

/// Sesli hikâyeyi paylaşılan [AppAudioHandler] (audio_service) üzerinden çalar —
/// böylece app kapansa/arka plana atılsa da çalmaya devam eder ve bildirimden
/// kumanda edilir.
class AudioStoryController extends Notifier<AudioStoryState> {
  AppAudioHandler get _h => ref.read(audioHandlerProvider);

  @override
  AudioStoryState build() {
    final sub = _h.player.playerStateStream.listen((s) {
      // Paylaşılan player'da BAŞKA kaynak (Kur'an) çalıyorken hikâye durumu
      // güncellenmesin — quran_audio_controller'daki guard'ın aynısı. Yoksa
      // Kur'an çalarken playing/loading buraya da sahte yansıyordu.
      if (_h.mode != 'story') return;
      state = state.copyWith(
        playing: s.playing,
        loading: s.processingState == ProcessingState.loading ||
            s.processingState == ProcessingState.buffering,
      );
      // 🏁 Son bölüm bitti (kuyruk sonu) → durdur + temizle → mini gizlenir.
      // Kur'an'dan farklı: hikâyede albümler arası otomatik geçiş YOK, düz
      // bitiş. just_audio 'completed'da playing=true bıraktığından temizlemezsek
      // mini "play" ikonuyla takılı kalırdı. Son şart: araya yeni liste
      // yüklemesi girdiyse (player artık completed değil) dokunma.
      if (s.processingState == ProcessingState.completed &&
          state.current != null &&
          _h.player.processingState == ProcessingState.completed) {
        stop();
      }
    });
    ref.onDispose(sub.cancel);
    return const AudioStoryState();
  }

  /// [lang] ile başlıklar çözülür (handler dile bağlı kalmasın diye).
  Future<void> play(AudioStoryCategory cat, int index, String lang) async {
    state = state.copyWith(current: cat, loading: true, playing: true);
    final list = [
      for (final e in cat.episodes)
        MediaTrack(
          id: e.id,
          url: e.audio,
          title: e.title(lang),
          artUri: e.cover.isNotEmpty ? e.cover : cat.cover,
          durationSec: e.durationSec,
        ),
    ];
    await _h.playPlaylist(list, albumTitle: cat.title(lang), startIndex: index);
  }

  Future<void> toggle() async {
    _h.player.playing ? await _h.pause() : await _h.play();
  }

  Future<void> stop() async {
    await _h.stop();
    state = state.copyWith(clear: true, playing: false, loading: false);
  }

  /// Paylaşılan player'a BAŞKA kaynak (Kur'an) geçince / tamamen durunca bayat
  /// durumumuzu sıfırlar — player'a DOKUNMAZ (yeni kaynağı o çalıyor olabilir).
  /// app.dart'taki tek onModeChanged bağı çağırır.
  void clearStale() {
    if (state.current != null || state.playing || state.loading) {
      state = const AudioStoryState();
    }
  }

  Future<void> next() => _h.skipToNext();
  Future<void> previous() => _h.skipToPrevious();
  Future<void> jumpTo(int index) => _h.player.seek(Duration.zero, index: index);
  Future<void> seek(Duration pos) => _h.player.seek(pos);

  int get currentIndex => _h.player.currentIndex ?? 0;
  Stream<int?> get currentIndexStream => _h.player.currentIndexStream;
  Stream<Duration> get positionStream => _h.player.positionStream;
  Stream<Duration?> get durationStream => _h.player.durationStream;

  /// Bu controller story modunda mı (mini-player görünürlüğü için).
  bool get isStoryMode => _h.mode == 'story';
}

final audioStoryControllerProvider =
    NotifierProvider<AudioStoryController, AudioStoryState>(
        AudioStoryController.new);
