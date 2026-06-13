import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app_image.dart';

const _videos = [
  'assets/videos/bg_1.mp4',
  'assets/videos/bg_2.mp4',
  'assets/videos/bg_3.mp4',
  'assets/videos/bg_4.mp4',
  'assets/videos/bg_5.mp4',
];

// Stable random starting clip per launch; the player then cycles through the
// rest in order and wraps around.
int? _startIndex;

/// A muted ambient video used as a card background. Plays every clip in
/// sequence — when one finishes it advances to the next and wraps around —
/// instead of looping a single clip. Falls back to [fallbackImage] until the
/// first clip is ready or if playback fails.
class VideoBackground extends StatefulWidget {
  final String fallbackImage;
  const VideoBackground({super.key, required this.fallbackImage});

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  VideoPlayerController? _controller;
  bool _ready = false;
  int _index = 0;
  bool _advancing = false;
  ValueListenable<bool>? _tickerMode;

  @override
  void initState() {
    super.initState();
    _index = _startIndex ??= Random().nextInt(_videos.length);
    _load(_index);
  }

  // PERF: ekran görünmezken (başka sekme — IndexedStack offstage — ya da
  // üstüne tam sayfa açılınca Navigator alttakini söndürür) video DURUR;
  // görünür olunca devam eder. Eskiden arka planda sürekli decode + her
  // karede tam ekran kompozisyon = gezinirken takılmanın ana kaynağıydı.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tm = TickerMode.getNotifier(context);
    if (!identical(tm, _tickerMode)) {
      _tickerMode?.removeListener(_onTickerModeChanged);
      _tickerMode = tm..addListener(_onTickerModeChanged);
      _onTickerModeChanged();
    }
  }

  void _onTickerModeChanged() {
    final c = _controller;
    if (c == null || !c.value.isInitialized || !mounted) return;
    if (_tickerMode?.value ?? true) {
      if (!c.value.isPlaying) c.play();
    } else {
      if (c.value.isPlaying) c.pause();
    }
  }

  Future<void> _load(int index) async {
    // mixWithOthers ŞART: video_player varsayılanı SES ODAĞI (audio focus)
    // ister — video sessiz (volume 0) olsa bile! Ana sayfaya her dönüşte bu
    // arka plan videosu odağı kapıp ÇALAN KUR'AN/HİKÂYEYİ DURDURUYORDU
    // (kullanıcı raporu). Dekoratif sessiz video odağa hiç karışmamalı.
    final controller = VideoPlayerController.asset(
      _videos[index],
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      await controller.setLooping(false); // advance to the next clip manually
      await controller.setVolume(0);
      controller.addListener(_onTick);
      // Görünmez sekmede klip değişimi olursa oynatmadan bekle.
      if (_tickerMode?.value ?? true) await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      // Swap the new clip in first (no black gap), then release the old one.
      final previous = _controller;
      setState(() {
        _controller = controller;
        _ready = true;
      });
      previous?.removeListener(_onTick);
      await previous?.dispose();
    } catch (_) {
      await controller.dispose();
    }
  }

  /// Advance to the next clip once the current one reaches its end.
  void _onTick() {
    // Duraklatılmışken (görünmez) "sonda + oynamıyor" koşulu yanlışlıkla
    // klip ilerletmesin.
    if (!(_tickerMode?.value ?? true)) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized || _advancing) return;
    final dur = c.value.duration;
    if (dur <= Duration.zero) return;
    final atEnd = c.value.position >= dur - const Duration(milliseconds: 120);
    if (atEnd && !c.value.isPlaying) {
      _advancing = true;
      _index = (_index + 1) % _videos.length;
      _load(_index).whenComplete(() => _advancing = false);
    }
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_onTickerModeChanged);
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_ready && c != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
      );
    }
    return AppImage(widget.fallbackImage, fit: BoxFit.cover);
  }
}
