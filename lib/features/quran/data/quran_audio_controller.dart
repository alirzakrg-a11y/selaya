import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/models/content.dart';
import '../../audio_stories/data/audio_handler.dart';
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

/// Kuran/Yâsîn sesli okumasını sesli-hikâyelerle **aynı** [AppAudioHandler]
/// (audio_service) üzerinden çalar → arka plan oynatma + bildirim kumandası +
/// mini-player. Aynı paylaşılan player; aynı anda ya hikâye ya Kuran çalar.
class QuranAudioController extends Notifier<QuranAudioState> {
  AppAudioHandler get _h => ref.read(audioHandlerProvider);

  @override
  QuranAudioState build() {
    final sub = _h.player.playerStateStream.listen((s) {
      if (_h.mode != 'quran') return;
      state = state.copyWith(
        playing: s.playing,
        loading: s.processingState == ProcessingState.loading ||
            s.processingState == ProcessingState.buffering,
      );
      // 🔁 Sure bitince OTOMATİK sıradaki sureye geç → Yâsîn/Kur'an kesintisiz okuma.
      if (s.processingState == ProcessingState.completed) {
        _advanceToNextSurah();
      }
    });
    ref.onDispose(sub.cancel);
    return const QuranAudioState();
  }

  bool _advancing = false;

  /// Çalan sure bitince sıradaki sureyi (N+1) yükleyip çalar — kesintisiz okuma.
  /// Nâs (114) bitince durur; sıradaki surenin sesli ayeti yoksa sessizce geçer.
  /// `completed` olayı arka arkaya birden çok gelebilir → [_advancing] kilidi
  /// çift geçişi/yeniden başlatmayı önler.
  Future<void> _advanceToNextSurah() async {
    if (_advancing) return;
    _advancing = true;
    try {
      await _doAdvance();
    } finally {
      _advancing = false;
    }
  }

  Future<void> _doAdvance() async {
    final cur = state.surahNumber;
    if (cur == null || cur >= 114) return;
    await _loadSurah(cur + 1, fromStart: true);
  }

  /// [target] suresini yükleyip çalar. [fromStart]=true → 1. ayet; false → SON
  /// sesli ayet (geri tuşuyla önceki surenin sonuna inmek için).
  Future<void> _loadSurah(int target, {required bool fromStart}) async {
    if (target < 1 || target > 114) return;
    final surahs = ref.read(surahsProvider).value ?? const <Surah>[];
    var name = 'Sure $target';
    for (final x in surahs) {
      if (x.number == target) {
        name = x.name(Intl.getCurrentLocale());
        break;
      }
    }
    try {
      final verses = await ref.read(versesProvider(target).future);
      final tracks = buildQuranTracks(target, name, verses, art);
      if (tracks.isNotEmpty) {
        await play(target, name, tracks, fromStart ? 0 : tracks.length - 1);
      }
    } catch (_) {}
  }

  Future<void> play(int surahNumber, String surahName, List<MediaTrack> tracks,
      int index) async {
    state = state.copyWith(
        surahNumber: surahNumber,
        surahName: surahName,
        loading: true,
        playing: true);
    await _h.playPlaylist(tracks,
        albumTitle: surahName, startIndex: index, mode: 'quran');
  }

  Future<void> toggle() async {
    _h.player.playing ? await _h.pause() : await _h.play();
  }

  Future<void> stop() async {
    await _h.stop();
    state = state.copyWith(clear: true, playing: false, loading: false);
  }

  Future<void> jumpTo(int index) => _h.player.seek(Duration.zero, index: index);

  /// ⏭ Sıradaki ayet — kuyruğun SONUNDAYSA sıradaki sureye geçer (manuel,
  /// otomatik geçişi beklemeden). 114'ün sonunda bir şey yapmaz.
  Future<void> next() async {
    final i = _h.player.currentIndex ?? 0;
    if (i < _h.tracks.length - 1) {
      await _h.skipToNext();
    } else {
      await _doAdvance();
    }
  }

  /// ⏮ Önceki ayet — kuyruğun BAŞINDAYSA önceki surenin son ayetine iner
  /// (Fâtiha'da başa sarar).
  Future<void> previous() async {
    final i = _h.player.currentIndex ?? 0;
    if (i > 0) {
      await _h.skipToPrevious();
    } else {
      final cur = state.surahNumber ?? 1;
      if (cur > 1) {
        await _loadSurah(cur - 1, fromStart: false);
      } else {
        await _h.player.seek(Duration.zero);
      }
    }
  }
  Future<void> seek(Duration pos) => _h.player.seek(pos);

  int get currentIndex => _h.player.currentIndex ?? 0;
  Stream<int?> get currentIndexStream => _h.player.currentIndexStream;
  Stream<Duration> get positionStream => _h.player.positionStream;
  Stream<Duration?> get durationStream => _h.player.durationStream;

  /// Çalan parçanın AYET numarası ('<sure>_<ayet>' kimliğinden) — kumandada
  /// "N. ayet okunuyor" göstermek için. Çözülemezse null.
  int? get currentAyahNumber {
    final i = _h.player.currentIndex;
    final t = _h.tracks;
    if (i == null || i < 0 || i >= t.length) return null;
    final p = t[i].id.split('_');
    return p.length >= 2 ? int.tryParse(p.last) : null;
  }

  /// Çalan listedeki parçalar (now-playing kuyruğu) + kapak (duvar kâğıdı URL).
  List<MediaTrack> get tracks => _h.tracks;
  String get art => _h.tracks.isNotEmpty ? _h.tracks.first.artUri : '';

  bool get isQuranMode => _h.mode == 'quran';
}

final quranAudioControllerProvider =
    NotifierProvider<QuranAudioController, QuranAudioState>(
        QuranAudioController.new);
