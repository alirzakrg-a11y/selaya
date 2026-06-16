import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/permissions_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/geometric_background.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/selaya_logo.dart';
import '../../../core/widgets/permission_dialog.dart';
import '../../notifications/data/daily_content_controller.dart';
import '../../notifications/data/prayer_notification_controller.dart';
import '../../notifications/data/special_notifications.dart';
import '../../settings/presentation/settings_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  static const _last = 6;
  bool _terms = false;
  bool _permIntroShown = false;
  // Drives the red "missing permissions" emphasis once the user tries to start.
  // The actual grant status is the single source of truth in
  // [permissionsControllerProvider].
  bool _warnPerms = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _page = i);
    // Show the "please read" permission warning once, when reaching setup.
    if (i == _last && !_permIntroShown) {
      _permIntroShown = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _autoRequestPerms());
    }
  }

  // İzinleri OTOMATİK iste — kurulum sayfasına gelince OS izin pencereleri
  // doğrudan açılır (kullanıcının ayrıca butona basmasına gerek kalmaz).
  Future<void> _autoRequestPerms() async {
    if (!mounted) return;
    final ctrl = ref.read(permissionsControllerProvider.notifier);
    await ctrl.requestNotifications(); // bildirim izni penceresi
    if (!mounted) return;
    await ctrl.useDeviceLocation(); // konum izni penceresi + konum çözümleme
    if (!mounted) return;
    await ctrl.refresh();
  }

  void _next() {
    // Terms must be accepted before leaving the first screen.
    if (_page == 0 && !_terms) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('onboarding.termsRequired'.tr())));
      return;
    }
    if (_page < _last) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
      return;
    }
    // On the setup page: if a required permission is missing, draw red borders
    // and warn once more before letting the user start.
    final perms = ref.read(permissionsControllerProvider);
    if (!perms.location || !perms.notifications) {
      setState(() => _warnPerms = true);
      _showPermWarning();
      return;
    }
    _finish();
  }

  Future<void> _showPermWarning() async {
    final c = context.colors;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: c.danger, size: 32),
        title: Text('onboarding.permWarnTitle'.tr()),
        content: Text('onboarding.permWarnBody'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('onboarding.permGrant'.tr(),
                style: TextStyle(color: c.gold, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('onboarding.permSkipAnyway'.tr(),
                style: TextStyle(color: c.textTertiary)),
          ),
        ],
      ),
    );
    if (proceed == true) _finish();
  }

  Future<void> _finish() async {
    await ref.read(sharedPreferencesProvider).setBool(PrefKeys.onboardingSeen, true);
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: GeometricBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text('onboarding.skip'.tr(),
                      style: TextStyle(color: c.textTertiary)),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: _onPageChanged,
                  children: [
                    const _LanguagePage(),
                    const _IntroPage(
                      image: 'assets/images/hero_mosque.jpg',
                      titleKey: 'onboarding.slide1Title',
                      descKey: 'onboarding.slide1Desc',
                    ),
                    const _IntroPage(
                      image: 'assets/images/inspiration_1.jpg',
                      titleKey: 'onboarding.slide2Title',
                      descKey: 'onboarding.slide2Desc',
                    ),
                    const _IntroPage(
                      image: 'assets/images/ai_bg.jpg',
                      titleKey: 'onboarding.slide3Title',
                      descKey: 'onboarding.slide3Desc',
                    ),
                    const _FeaturesShowcasePage(),
                    const _NotificationPrefsPage(),
                    _SetupPage(warn: _warnPerms),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    if (_page == 0) ...[
                      _TermsRow(
                        accepted: _terms,
                        onChanged: (v) => setState(() => _terms = v),
                      ),
                      const Gap.md(),
                    ],
                    SmoothPageIndicator(
                      controller: _controller,
                      count: _last + 1,
                      effect: ExpandingDotsEffect(
                        dotHeight: 7,
                        dotWidth: 7,
                        spacing: 6,
                        activeDotColor: c.gold,
                        dotColor: c.border,
                      ),
                    ),
                    const Gap.lg(),
                    GradientButton(
                      label: _page == _last
                          ? 'onboarding.getStarted'.tr()
                          : 'onboarding.next'.tr(),
                      icon: _page == _last ? AppIcons.check : AppIcons.forward,
                      expand: true,
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguagePage extends StatelessWidget {
  const _LanguagePage();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = context.locale.languageCode;
    Widget option(String code, String label) {
      final sel = current == code;
      return GestureDetector(
        onTap: () => context.setLocale(Locale(code)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            color: sel ? c.gold.withValues(alpha: 0.14) : c.surfaceAlt,
            borderRadius: AppRadius.rLg,
            border: Border.all(color: sel ? c.gold : c.border, width: sel ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Text(code == 'tr' ? '🇹🇷' : '🇬🇧', style: const TextStyle(fontSize: 22)),
              const Gap.md(),
              Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.titleMedium)),
              if (sel) Icon(AppIcons.checkCircle, color: c.gold),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SelayaLogo(size: 104),
          const Gap.lg(),
          Text('onboarding.greeting'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: c.gold, fontWeight: FontWeight.w700)),
          const Gap.xs(),
          Text('common.slogan'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textSecondary)),
          const Gap.xl(),
          Text('onboarding.chooseLanguage'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: c.gold)),
          const Gap.sm(),
          option('tr', 'settings.turkish'.tr()),
          option('en', 'settings.english'.tr()),
        ],
      ),
    );
  }
}

/// Terms & privacy consent — required before leaving the first screen.
class _TermsRow extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;
  const _TermsRow({required this.accepted, required this.onChanged});

  void _showTerms(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('onboarding.termsLink'.tr(),
                  style: Theme.of(context).textTheme.titleLarge),
              const Gap.md(),
              Text('onboarding.termsBody'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.6, color: context.colors.textSecondary)),
              const Gap.md(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: accepted,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: c.gold,
                checkColor: const Color(0xFF1A1203),
                side: BorderSide(color: c.border),
              ),
            ),
            const Gap.sm(),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(!accepted),
                child: Text('onboarding.termsAccept'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary)),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: GestureDetector(
            onTap: () => _showTerms(context),
            child: Text('onboarding.termsLink'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.gold,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline)),
          ),
        ),
      ],
    );
  }
}

class _IntroPage extends StatelessWidget {
  final String image;
  final String titleKey;
  final String descKey;
  const _IntroPage(
      {required this.image, required this.titleKey, required this.descKey});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: AppRadius.rXxl,
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(image),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC05070D)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap.xl(),
          Text(titleKey.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const Gap.sm(),
          Text(descKey.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

/// İlk açılış vitrini — uygulamadaki TÜM ana özellikleri tek bakışta tanıtır.
class _FeaturesShowcasePage extends StatelessWidget {
  const _FeaturesShowcasePage();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isTr = context.langCode == 'tr';
    final feats = <(IconData, String, String)>[
      (
        Icons.access_time_filled_rounded,
        isTr ? 'Namaz Vakitleri & Ezan' : 'Prayer Times & Adhan',
        isTr
            ? 'Tam ekran alarm, ezan sesi, vakitten önce hatırlatma'
            : 'Full-screen alarm, adhan, pre-time reminders'
      ),
      (
        Icons.menu_book_rounded,
        'Kur\'an-ı Kerim',
        isTr
            ? 'Sureler, cüzler, dinleme ve yer imleri'
            : 'Surahs, juz, audio and bookmarks'
      ),
      (
        Icons.explore_rounded,
        isTr ? 'Kıble Pusulası' : 'Qibla Compass',
        isTr
            ? 'Bulunduğun yerden Kâbe yönü'
            : 'Direction of the Kaaba from your location'
      ),
      (
        Icons.touch_app_rounded,
        'Zikirmatik',
        isTr ? 'Dijital tesbih, zikir sayacı' : 'Digital tasbih counter'
      ),
      (
        Icons.volunteer_activism_rounded,
        isTr ? 'Dualar & Esmaül Hüsna' : 'Duas & 99 Names',
        isTr
            ? 'Günlük dualar ve Allah\'ın güzel isimleri'
            : 'Daily duas and the 99 beautiful names'
      ),
      (
        Icons.auto_awesome_rounded,
        'SELAYA AI',
        isTr
            ? 'Dini sorularına kaynaklı, anında cevap'
            : 'Instant, sourced answers to religious questions'
      ),
      (
        Icons.format_quote_rounded,
        isTr ? 'Ayetler & Hadisler' : 'Verses & Hadiths',
        isTr ? 'Beğen, favorile, paylaş' : 'Like, favorite, share'
      ),
      (
        Icons.mosque_rounded,
        isTr ? 'Cami Rehberi' : 'Mosque Finder',
        isTr ? 'Yakındaki camileri bul' : 'Find nearby mosques'
      ),
      (
        Icons.bar_chart_rounded,
        isTr ? 'İbadet & Oruç Takibi' : 'Worship & Fast Tracking',
        isTr
            ? 'Namaz ve oruçlarını kaydet, geçmişini gör'
            : 'Log prayers and fasts, view your history'
      ),
      (
        Icons.headphones_rounded,
        isTr ? 'Sesli Hikâyeler & Duvar Kâğıtları' : 'Audio Stories & Wallpapers',
        isTr ? 'Dinle, indir, paylaş' : 'Listen, download, share'
      ),
      (
        Icons.calendar_month_rounded,
        isTr ? 'İslami Takvim & Kandiller' : 'Islamic Calendar & Holy Nights',
        isTr
            ? 'Dini günler ve kandil hatırlatmaları'
            : 'Religious days and holy-night reminders'
      ),
    ];
    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap.md(),
          Text(isTr ? 'SELAYA\'da Neler Var?' : 'What\'s in SELAYA?',
              style: Theme.of(context).textTheme.headlineSmall),
          const Gap.xs(),
          Text(
              isTr
                  ? 'İhtiyacın olan her şey tek uygulamada 🌙'
                  : 'Everything you need, in one app 🌙',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textSecondary)),
          const Gap.md(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              itemCount: feats.length,
              separatorBuilder: (_, _) => const Gap.sm(),
              itemBuilder: (ctx, i) {
                final f = feats[i];
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.gold.withValues(alpha: 0.13)),
                      child: Icon(f.$1, color: c.gold, size: 20),
                    ),
                    const Gap.md(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(f.$3,
                              style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                  height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Senior-friendly explainer + big toggles for the notifications SELAYA sets up
/// for the user: the persistent "next prayer" bar, the full-screen adhan alarm,
/// and the daily verse + hadith. All default ON; turning one off here persists
/// immediately (daily ones are (re)scheduled/cancelled on the spot). Prayer
/// reminders + the adhan sound are pre-configured and tunable later in Settings.
class _NotificationPrefsPage extends ConsumerWidget {
  const _NotificationPrefsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lang = context.langCode;
    final alerts = ref.watch(prayerAlertsProvider);
    final ongoing = ref.watch(ongoingNotificationProvider);
    final ayah = ref.watch(dailyAyahNotifProvider);
    final hadith = ref.watch(dailyHadithNotifProvider);
    final vibration = ref.watch(notifVibrationProvider);
    final kandil = ref.watch(kandilNotifProvider);
    final cuma = ref.watch(cumaNotifProvider);

    return Padding(
      padding: AppSpacing.screen,
      child: ListView(
        children: [
          const Gap.md(),
          Icon(Icons.notifications_active_rounded, color: c.gold, size: 40),
          const Gap.sm(),
          Text('onboarding.prefsTitle'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const Gap.sm(),
          Text('onboarding.prefsIntro'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: c.textSecondary, height: 1.5)),
          const Gap.lg(),
          // Master switch — turning this off in setup means no adhan/prayer
          // alerts at all (the user can opt in later in Settings).
          _PrefToggleCard(
            icon: Icons.notifications_active_rounded,
            title: 'onboarding.prefAlertsTitle'.tr(),
            desc: 'onboarding.prefAlertsDesc'.tr(),
            value: alerts,
            onChanged: (v) => ref.read(prayerAlertsProvider.notifier).set(v),
          ),
          const Gap.md(),
          _PrefToggleCard(
            icon: Icons.timelapse_rounded,
            title: 'onboarding.prefOngoingTitle'.tr(),
            desc: 'onboarding.prefOngoingDesc'.tr(),
            value: ongoing,
            onChanged: (v) =>
                ref.read(ongoingNotificationProvider.notifier).set(v),
          ),
          const Gap.md(),
          _PrefToggleCard(
            icon: Icons.auto_stories_rounded,
            title: 'onboarding.prefAyahTitle'.tr(),
            desc: 'onboarding.prefAyahDesc'.tr(),
            value: ayah,
            onChanged: (v) async {
              await ref.read(dailyAyahNotifProvider.notifier).set(v);
              await applyDailyAyah(ref, lang, v);
            },
          ),
          const Gap.md(),
          _PrefToggleCard(
            icon: Icons.menu_book_rounded,
            title: 'onboarding.prefHadithTitle'.tr(),
            desc: 'onboarding.prefHadithDesc'.tr(),
            value: hadith,
            onChanged: (v) async {
              await ref.read(dailyHadithNotifProvider.notifier).set(v);
              await applyDailyHadith(ref, lang, v);
            },
          ),
          const Gap.md(),
          _PrefToggleCard(
            icon: Icons.vibration_rounded,
            title: lang == 'tr' ? 'Titreşim' : 'Vibration',
            desc: lang == 'tr'
                ? 'Bildirimler gelince telefon titresin.'
                : 'Vibrate the phone on notifications.',
            value: vibration,
            onChanged: (v) => ref.read(notifVibrationProvider.notifier).set(v),
          ),
          const Gap.md(),
          _PrefToggleCard(
            icon: Icons.nightlight_round,
            title:
                lang == 'tr' ? 'Kandiller & Dini Günler' : 'Holy Nights & Days',
            desc: lang == 'tr'
                ? 'Kandil ve özel günlerde hatırlatma al.'
                : 'Get reminders on holy nights and special days.',
            value: kandil,
            onChanged: (v) => ref.read(kandilNotifProvider.notifier).set(v),
          ),
          const Gap.md(),
          _PrefToggleCard(
            icon: Icons.view_week_rounded,
            title: lang == 'tr' ? 'Cuma Hatırlatması' : 'Friday Reminder',
            desc: lang == 'tr'
                ? 'Her Cuma "Hayırlı Cumalar" mesajı.'
                : 'A "Blessed Friday" message each week.',
            value: cuma,
            onChanged: (v) => ref.read(cumaNotifProvider.notifier).set(v),
          ),
          const Gap.lg(),
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.08),
              borderRadius: AppRadius.rLg,
              border: Border.all(color: c.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: c.gold, size: 20),
                const Gap.sm(),
                Expanded(
                  child: Text('onboarding.prefsFooter'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: c.textSecondary, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Large, senior-friendly on/off card: a gold icon disc, a bold title, an
/// explanatory line, and a switch — used on the notification-preferences page.
class _PrefToggleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PrefToggleCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: AppRadius.rLg,
        border:
            Border.all(color: value ? c.gold.withValues(alpha: 0.5) : c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: c.gold, size: 24),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.textSecondary, height: 1.35)),
              ],
            ),
          ),
          const Gap.sm(),
          Switch(value: value, onChanged: onChanged, activeThumbColor: c.gold),
        ],
      ),
    );
  }
}

class _SetupPage extends ConsumerWidget {
  final bool warn;
  const _SetupPage({required this.warn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lang = context.langCode;
    final method = ref.watch(settingsProvider).calcMethod;
    final perms = ref.watch(permissionsControllerProvider);
    final allGranted = perms.location && perms.notifications;

    return Padding(
      padding: AppSpacing.screen,
      child: ListView(
        children: [
          Text('onboarding.ready'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const Gap.lg(),
          // Red-bordered permission warning — emphasised once the user tries to
          // start without granting, dismissed (green) once everything is granted.
          if (!allGranted)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: warn ? 0.14 : 0.07),
                borderRadius: AppRadius.rLg,
                border: Border.all(
                    color: c.danger, width: warn ? 2.2 : 1.4),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: c.danger, size: 22),
                  const Gap.sm(),
                  Expanded(
                    child: Text('onboarding.permWarnBanner'.tr(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.danger, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          _LocationPermTile(granted: perms.location, warn: warn),
          const Gap.md(),
          _PermTile(
            icon: AppIcons.notification,
            title: 'onboarding.permissionNotifTitle'.tr(),
            desc: 'onboarding.permissionNotifDesc'.tr(),
            granted: perms.notifications,
            warn: warn,
            onTap: () async {
              final outcome = await ref
                  .read(permissionsControllerProvider.notifier)
                  .requestNotifications();
              if (!context.mounted) return;
              if (outcome.needsSettings) {
                await showOpenSettingsDialog(
                    context, ref.read(permissionServiceProvider),
                    title: 'notif.permissionDeniedTitle'.tr(),
                    message: 'notif.permissionDeniedBody'.tr());
              }
            },
          ),
          // Battery optimization (Doze) exemption — Android only. Without it the
          // OS can delay/drop background prayer alarms. Recommended, not required.
          if (Platform.isAndroid) ...[
            const Gap.md(),
            _PermTile(
              icon: AppIcons.battery,
              title: 'onboarding.permissionBatteryTitle'.tr(),
              desc: 'onboarding.permissionBatteryDesc'.tr(),
              granted: perms.batteryExempt,
              warn: warn,
              onTap: () => ref
                  .read(permissionsControllerProvider.notifier)
                  .requestBatteryExemption(),
            ),
          ],
          const Gap.lg(),
          Text('onboarding.methodTitle'.tr(),
              style: Theme.of(context).textTheme.titleMedium),
          const Gap.sm(),
          RadioGroup<CalcMethod>(
            groupValue: method,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setCalcMethod(v!),
            child: Column(
              children: [
                for (final m in [
                  CalcMethod.diyanet,
                  CalcMethod.mwl,
                  CalcMethod.egypt
                ])
                  RadioListTile<CalcMethod>(
                    value: m,
                    activeColor: c.gold,
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.label(lang),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool granted;
  final bool warn;
  final bool busy;
  final VoidCallback onTap;
  const _PermTile({
    required this.icon,
    required this.title,
    required this.desc,
    required this.granted,
    this.warn = false,
    this.busy = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final flagged = warn && !granted;
    return InkWell(
      onTap: granted ? null : onTap,
      borderRadius: AppRadius.rLg,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: flagged ? c.danger.withValues(alpha: 0.06) : c.surfaceAlt,
          borderRadius: AppRadius.rLg,
          border: Border.all(
              color: granted
                  ? c.success.withValues(alpha: 0.6)
                  : (flagged ? c.danger : c.border),
              width: flagged ? 1.8 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: granted ? c.success : c.gold),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(desc,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textTertiary)),
                ],
              ),
            ),
            if (busy)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.gold),
              )
            else
              Icon(granted ? AppIcons.checkCircle : AppIcons.forward,
                  color: granted ? c.success : c.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Location permission tile. Delegates the whole request → fix → save-city flow
/// to [PermissionsController], which flips the permission state to granted the
/// instant permission is granted (so the tile turns green via `perms.location`
/// without waiting on the up-to-12s GPS fix). This widget just shows a spinner
/// during the background resolve and surfaces the failure cases.
class _LocationPermTile extends ConsumerStatefulWidget {
  final bool granted;
  final bool warn;
  const _LocationPermTile({required this.granted, required this.warn});

  @override
  ConsumerState<_LocationPermTile> createState() => _LocationPermTileState();
}

class _LocationPermTileState extends ConsumerState<_LocationPermTile> {
  bool _busy = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    final result = await ref
        .read(permissionsControllerProvider.notifier)
        .useDeviceLocation();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case LocationFlowResult.needsSettings:
        await showOpenSettingsDialog(
            context, ref.read(permissionServiceProvider),
            title: 'settings.locationPermTitle'.tr(),
            message: 'settings.locationPermBody'.tr());
      case LocationFlowResult.noFix:
        // Permission on, but no fix (indoors / emulator / GPS off): the tile
        // stays granted; nudge the user toward manual city selection.
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('onboarding.locationResolveFailed'.tr())));
      case LocationFlowResult.denied:
      case LocationFlowResult.saved:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PermTile(
      icon: AppIcons.location,
      title: 'onboarding.permissionLocationTitle'.tr(),
      desc: 'onboarding.permissionLocationDesc'.tr(),
      granted: widget.granted,
      warn: widget.warn,
      busy: _busy,
      onTap: _request,
    );
  }
}
