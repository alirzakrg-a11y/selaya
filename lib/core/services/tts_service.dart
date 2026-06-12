import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper over [FlutterTts] used for the "sesli oku" (read-aloud) feature
/// on screens without a recorded audio source — Dualar and Esmaül Hüsna. The
/// device's own speech engine reads the text, so no audio assets are needed.
///
/// [speaking] reflects the live state for the transport bar; [speak] takes an
/// optional [onComplete] used to auto-advance to the next item in a list.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);
  VoidCallback? _onComplete;
  bool _inited = false;

  Future<void> _init() async {
    if (_inited) return;
    _inited = true;
    _tts.setStartHandler(() => speaking.value = true);
    _tts.setCompletionHandler(() {
      speaking.value = false;
      final cb = _onComplete;
      _onComplete = null;
      cb?.call(); // auto-advance, if the caller asked for it
    });
    _tts.setCancelHandler(() => speaking.value = false);
    _tts.setPauseHandler(() => speaking.value = false);
    _tts.setErrorHandler((_) => speaking.value = false);
  }

  /// Speaks [text] in [lang] (e.g. 'tr-TR'). Cancels any current utterance first.
  Future<void> speak(
    String text, {
    String lang = 'tr-TR',
    double rate = 0.45,
    VoidCallback? onComplete,
  }) async {
    await _init();
    _onComplete = null; // the upcoming stop() must not trigger the old callback
    await _tts.stop();
    _onComplete = onComplete;
    try {
      await _tts.setLanguage(lang);
    } catch (_) {}
    try {
      await _tts.setSpeechRate(rate);
    } catch (_) {}
    try {
      await _tts.speak(text);
    } catch (_) {
      speaking.value = false;
    }
  }

  Future<void> stop() async {
    _onComplete = null;
    await _tts.stop();
    speaking.value = false;
  }

  void dispose() {
    _tts.stop();
    speaking.dispose();
  }
}

/// App-wide shared TTS engine (one utterance at a time).
final ttsServiceProvider = Provider<TtsService>((ref) {
  final s = TtsService();
  ref.onDispose(s.dispose);
  return s;
});
