import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Play / App Store **uygulama içi değerlendirme** (yıldız) akışı.
/// `requestReview()` native değerlendirme penceresini gösterir (uygulamadan
/// ÇIKMADAN); kullanılamıyorsa mağaza sayfasını açar. Google gösterim sıklığını
/// KENDİSİ sınırlar (kota) → "her seferinde çıkar" garantisi YOKTUR.
class ReviewService {
  static final InAppReview _iar = InAppReview.instance;
  static const _lastAskKey = 'review_last_ask_ms';

  /// Manuel — "Bizi Değerlendir" düğmesinden. Native akış yoksa mağaza sayfası.
  static Future<void> openReview() async {
    // Uygulama-içi akış (Play'den kurulu + kullanılabilir) → native pencere.
    try {
      if (await _iar.isAvailable()) {
        await _iar.requestReview();
        return;
      }
    } catch (_) {
      // sideload / kapalı test → in-app akış "hata" verir; mağaza sayfasına düş.
    }
    // Yedek: Play mağaza sayfasını aç (her durumda çalışır).
    try {
      await _iar.openStoreListing();
    } catch (_) {}
  }

  /// Otomatik — yeterince kullanıldıysa (≥4. açılış) ve son sormadan beri ≥45 gün
  /// geçtiyse uygun bir anda değerlendirme penceresini iste. Açılışı bölmemek için
  /// çağıran tarafça GECİKMELİ çağrılır.
  static Future<void> maybeRequest(
      SharedPreferences prefs, int launchCount, int nowMs) async {
    if (launchCount < 4) return;
    final last = prefs.getInt(_lastAskKey) ?? 0;
    const minGapMs = 1000 * 60 * 60 * 24 * 45; // 45 gün
    if (last != 0 && nowMs - last < minGapMs) return;
    try {
      if (!await _iar.isAvailable()) return;
      await prefs.setInt(_lastAskKey, nowMs);
      await _iar.requestReview();
    } catch (_) {}
  }
}
