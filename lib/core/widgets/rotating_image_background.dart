import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_image.dart';

/// Hero kart arka planı için HAFİF görsel döndürücü — videonun yerine.
///
/// Eski telefonlarda arka plan videosu sürekli decode + kompozisyon yüzünden
/// takılma yapıyordu. Bunun yerine panel/CDN görselleri ([images]) arasında
/// her [interval]'de yumuşak bir cross-fade ile geçer (geçiş dışında TAMAMEN
/// statik — boşa kare üretmez). [images] boşsa / yüklenene kadar [fallback]
/// (yerel asset) gösterilir. Görünmezken (başka sekme — IndexedStack offstage)
/// zamanlayıcı durur.
class RotatingImageBackground extends StatefulWidget {
  final List<String> images;
  final String fallback;
  final Duration interval;
  const RotatingImageBackground({
    super.key,
    required this.images,
    required this.fallback,
    this.interval = const Duration(seconds: 7),
  });

  @override
  State<RotatingImageBackground> createState() =>
      _RotatingImageBackgroundState();
}

class _RotatingImageBackgroundState extends State<RotatingImageBackground> {
  int _i = 0;
  Timer? _timer;
  ValueListenable<TickerModeData>? _tm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tm = TickerMode.getValuesNotifier(context);
    if (!identical(tm, _tm)) {
      _tm?.removeListener(_sync);
      _tm = tm..addListener(_sync);
    }
    _sync();
  }

  /// Görünür + birden çok görsel varsa döndürmeyi başlat; değilse durdur.
  void _sync() {
    final visible = _tm?.value.enabled ?? true;
    if (visible && widget.images.length > 1) {
      _timer ??= Timer.periodic(widget.interval, (_) {
        if (mounted) setState(() => _i = (_i + 1) % widget.images.length);
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void didUpdateWidget(RotatingImageBackground old) {
    super.didUpdateWidget(old);
    // Görsel listesi sonradan geldi (CDN yüklendi) → sayaç + döngüyü tazele.
    if (old.images.length != widget.images.length) {
      if (widget.images.isNotEmpty) _i %= widget.images.length;
      _timer?.cancel();
      _timer = null;
      _sync();
    }
  }

  @override
  void dispose() {
    _tm?.removeListener(_sync);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    final String tag;
    final Widget pic;
    if (imgs.isEmpty) {
      tag = 'rib-fallback';
      pic = Image.asset(widget.fallback, fit: BoxFit.cover);
    } else {
      final url = imgs[_i % imgs.length];
      tag = url;
      pic = AppImage.cdn(url, fit: BoxFit.cover, memWidth: 720);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      // Anahtar değişince (görsel döndü) çapraz-solma; aksi halde statik.
      child: SizedBox.expand(key: ValueKey(tag), child: pic),
    );
  }
}
