import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/cdn.dart';
import '../theme/app_colors.dart';

/// Görseli önce (disk-önbellekli) ağdan, sonra paketteki asset'ten, en sonda
/// altın gradyandan çizer — yani CDN içeriği çevrimiçi yüklenir ama çevrimdışı
/// güvenli kalır.
class AppImage extends StatelessWidget {
  final String? asset;

  /// İsteğe bağlı CDN/ağ URL'si; verilirse önce o yüklenir (disk-önbellekli) ve
  /// paketteki [asset] (varsa) placeholder / çevrimdışı yedeği olarak gösterilir.
  final String? networkUrl;

  final BoxFit fit;
  final double? width;
  final double? height;
  final List<Color>? fallbackColors;

  /// Verilirse görsel bellekte en fazla bu genişlikte decode edilir —
  /// uzun ızgaralarda (yüzlerce görsel) RAM ve kaydırma takılmasını düşürür.
  final int? memWidth;

  /// Verilirse, AĞ görseli (disk-önbellekte yokken) İNDİRİLİRKEN paket-yedeği
  /// yerine BU gösterilir — ör. mushaf sayfası inerken küçük "Sayfa indiriliyor…"
  /// bilgisi. Sadece [networkUrl] modunda etkili.
  final Widget? loadingPlaceholder;

  const AppImage(
    this.asset, {
    super.key,
    this.networkUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallbackColors,
    this.memWidth,
    this.loadingPlaceholder,
  });

  /// Asset yolu VEYA tam CDN URL'si kabul eder; ikisini de çözüp ağdan
  /// (paket yedeğiyle) yükler. Böylece listeler hem paket hem panel içeriği
  /// taşıdığında tek çağrı yeterli olur.
  ///   "assets/images/x.jpg"            -> ağ: cdn/images/x.jpg, yedek: asset
  ///   "https://cdn.selaya.app/.../x"   -> ağ: o URL, yedek: paketteki eşi
  factory AppImage.cdn(
    String? imageOrUrl, {
    Key? key,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    List<Color>? fallbackColors,
    int? memWidth,
    Widget? loadingPlaceholder,
  }) {
    final v = imageOrUrl ?? '';
    String? asset;
    String? net;
    if (v.startsWith('http')) {
      net = v;
      final fb = SelayaCdn.assetForUrl(v);
      asset = fb.isEmpty ? null : fb;
    } else if (v.startsWith('assets/')) {
      asset = v;
      final u = SelayaCdn.urlForAsset(v);
      net = u.isEmpty ? null : u;
    } else if (v.isNotEmpty) {
      asset = v;
    }
    return AppImage(
      asset,
      key: key,
      networkUrl: net,
      fit: fit,
      width: width,
      height: height,
      fallbackColors: fallbackColors,
      memWidth: memWidth,
      loadingPlaceholder: loadingPlaceholder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _fallback(context);

    if (networkUrl != null && networkUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl!,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memWidth,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => loadingPlaceholder ?? _bundled(fallback),
        errorWidget: (_, _, _) => _bundled(fallback),
      );
    }
    return _bundled(fallback);
  }

  Widget _bundled(Widget fallback) {
    if (asset == null || asset!.isEmpty) return fallback;
    return Image.asset(
      asset!,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _fallback(BuildContext context) {
    final c = context.colors;
    final colors =
        fallbackColors ?? [c.goldDeep.withValues(alpha: 0.55), c.surface, c.bg];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}
