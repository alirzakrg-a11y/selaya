import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/content_providers.dart';
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
    // Animasyon kaldırıldığından bekleme kısaldı (1600→600ms): sade logo kısa
    // görünür, hızlıca ana ekrana geçer.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final seen =
        ref.read(sharedPreferencesProvider).getBool(PrefKeys.onboardingSeen) ?? false;
    context.go(seen ? Routes.home : Routes.intro);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: GeometricBackground(
        patternOpacity: 0.07,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animasyon İPTAL (kullanıcı 2026-06-14): fade/scale/shimmer, soğuk
              // ilk açılışta kekeme görünüp "donma" hissini artırıyordu → sade,
              // statik logo + slogan.
              const SelayaLogo(size: 150),
              const SizedBox(height: 12),
              Text(
                'common.slogan'.tr(),
                style: TextStyle(
                    color: context.colors.textSecondary,
                    letterSpacing: 1,
                    fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
