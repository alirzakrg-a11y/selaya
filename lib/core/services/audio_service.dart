import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// A single shared `just_audio` player used for app media (Sesli Hikayeler).
///
/// The Quran reader keeps its own short-lived player. Background / lock-screen
/// media controls (just_audio_background) are a deferred enhancement — enabling
/// it would force MediaItem tags on every source app-wide, so it's intentionally
/// left out here to keep playback simple and stable.
class AudioService {
  final AudioPlayer player = AudioPlayer();

  Stream<int?> get currentIndexStream => player.currentIndexStream;
  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;
  Stream<bool> get playingStream => player.playingStream;

  bool get playing => player.playing;
  int? get currentIndex => player.currentIndex;

  Future<void> setPlaylist(List<AudioSource> sources,
      {int initialIndex = 0}) async {
    if (sources.isEmpty) return;
    await player.setAudioSources(sources, initialIndex: initialIndex);
  }

  Future<void> play() => player.play();
  Future<void> pause() => player.pause();
  Future<void> togglePlay() => player.playing ? player.pause() : player.play();
  Future<void> seek(Duration pos) => player.seek(pos);
  Future<void> seekToIndex(int index) => player.seek(Duration.zero, index: index);
  Future<void> next() => player.seekToNext();
  Future<void> previous() => player.seekToPrevious();
  Future<void> stop() => player.stop();
}

/// App-wide shared media player (kept alive for the app lifetime).
final audioPlayerProvider = Provider<AudioService>((ref) {
  final svc = AudioService();
  ref.onDispose(() => svc.player.dispose());
  return svc;
});
