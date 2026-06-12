/// SELAYA Cloudflare uç noktaları (R2 CDN + içerik API'si).
///
/// R2'deki anahtarlar, app'teki asset yolunu `assets/` öneki olmadan yansıtır:
///   assets/images/wallpapers/x.jpg  ->  https://cdn.selaya.app/images/wallpapers/x.jpg
class SelayaCdn {
  SelayaCdn._();

  static const String cdnBase = 'https://cdn.selaya.app';
  static const String apiBase = 'https://api.selaya.app';
  static const String manifestUrl = '$apiBase/v1/manifest';

  /// Bir CDN URL'sinden, offline yedeği olarak kullanılabilecek paket-içi asset
  /// yolunu üretir (yeni/panelden eklenen içerik için pakette bulunmayabilir).
  ///   https://cdn.selaya.app/images/wallpapers/x.jpg -> assets/images/wallpapers/x.jpg
  static String assetForUrl(String? url) {
    if (url == null || !url.startsWith(cdnBase)) return '';
    final rest = url.substring(cdnBase.length).replaceFirst(RegExp(r'^/'), '');
    return rest.isEmpty ? '' : 'assets/$rest';
  }

  /// Paket-içi bir asset yolunu CDN URL'sine çevirir (gerekirse).
  ///   assets/images/wallpapers/x.jpg -> https://cdn.selaya.app/images/wallpapers/x.jpg
  static String urlForAsset(String assetPath) {
    final p = assetPath.replaceAll('\\', '/');
    if (!p.startsWith('assets/')) return '';
    return '$cdnBase/${p.substring('assets/'.length)}';
  }
}
