import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/data/manifest_service.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/widget_service.dart';
import '../../hatim/data/hatim_reminder.dart';
import '../../notifications/data/daily_content_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/geometric_background.dart';
import '../../../core/widgets/selaya_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapDailyContent();
      _go();
    });
  }

  /// Push today's hadith to the home-screen widget, and (re)apply the daily
  /// verse + hadith lock-screen notifications according to the user's *persisted*
  /// choice (so they survive restarts and stay consistent across launches).
  Future<void> _bootstrapDailyContent() async {
    try {
      final lang = context.langCode;
      final hadiths = await ref.read(hadithsProvider.future);
      if (mounted && hadiths.isNotEmpty) {
        final h = hadiths[DateTime.now().day % hadiths.length];
        final label = lang == 'tr' ? 'Günün Hadisi' : 'Hadith of the Day';
        await ref.read(widgetServiceProvider).updateHadith(
            text: h.text(lang), reference: h.collection, label: label);
      }
      if (!mounted) return;
      await applyDailyHadith(ref, lang, ref.read(dailyHadithNotifProvider));
      if (!mounted) return;
      await applyDailyAyah(ref, lang, ref.read(dailyAyahNotifProvider));
      if (!mounted) return;
      await applyHatimReminder(ref, lang); // hatim hatırlatmasını yeniden kur
    } catch (_) {}
  }

  Future<void> _go() async {
    // İLK AÇILIŞ "DOLMA" SÜRECİ (kullanıcı 2026-06-15): panel/manifest içeriği
    // GELENE KADAR splash'te bekle → ana ekran DOLU açılsın; "açılıp sonradan
    // içerik dolarken donma"/pop-in olmasın. Yavaş/çevrimdışı ağda takılmamak
    // için en fazla 6 sn bekle (o sürede gelmezse önbellek/paket yedeğiyle yine
    // de geç). Sonraki açılışlarda manifest ÖNBELLEKTEN anında gelir → splash
    // kısa kalır (alttaki min 1.2 sn yüzünden ekran çakmaz).
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 1200));
    Future<void> loadContent() async {
      try {
        await ref
            .read(manifestProvider.future)
            .timeout(const Duration(seconds: 6));
      } catch (_) {/* zaman aşımı/çevrimdışı → yedek devrede, yine de geç */}
    }

    await Future.wait([minSplash, loadContent()]);
    if (!mounted) return;
    final seen =
        ref.read(sharedPreferencesProvider).getBool(PrefKeys.onboardingSeen) ??
            false;
    context.go(seen ? Routes.home : Routes.intro);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: GeometricBackground(
        patternOpacity: 0.07,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animasyon kaldırıldı (kullanıcı 2026-06-15 "açılışta donmasın"):
              // soğuk ilk açılışta fade/scale/shimmer kekeme görünüp donma
              // hissini artırıyordu → sade statik logo + slogan.
              const SelayaLogo(size: 150),
              const SizedBox(height: 12),
              Text(
                'common.slogan'.tr(),
                style: TextStyle(
                    color: c.textSecondary, letterSpacing: 1, fontSize: 13),
              ),
              const SizedBox(height: 32),
              // "Dolma" göstergesi: panel içeriği yüklenirken döner; içerik hazır
              // olunca (veya 6 sn dolunca) splash kapanıp ana ekran açılır.
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: c.gold.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
