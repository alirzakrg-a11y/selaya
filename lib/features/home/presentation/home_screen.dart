import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/overpass_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/share/share_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/feature_icon.dart';
import '../../../core/widgets/like_button.dart';
import '../../../core/widgets/geometric_background.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/data/auth_controller.dart';
import '../../social_feed/data/video_thumbs.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../ibadah_tracking/data/prayer_checkin.dart';
import '../../prayer_times/presentation/widgets/next_prayer_card.dart';
import '../../prayer_times/presentation/widgets/prayer_clock_dial.dart';
import '../../prayer_times/presentation/widgets/prayer_strip.dart';
import '../../quiz/data/quiz_models.dart';
import '../../prayer_times/presentation/widgets/prayer_timeline_gauge.dart';
import '../../stories/presentation/story_rail.dart';
import '../../weather/data/weather_service.dart';
import '../data/featured_tools.dart';
import '../data/home_layout_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // On home open, collect every fard prayer whose time has passed today and
    // show one popup to tick the ones prayed → logs to İbadet Takibi (#4).
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPrayerCheckIn());
  }

  Future<void> _askPrayerCheckIn() async {
    final pending = await pendingPrayerCheckIns(ref);
    if (pending.isEmpty || !mounted || !context.mounted) return;
    await showPrayerCheckInBatch(context, ref, pending);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: GeometricBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            children: [
              const _HomeHeader(),
              const _LocationWarningBanner(),
              const Gap.md(),
              // Tüm bölümler kullanıcı sırasına/gizlemesine göre (header hariç).
              for (final k in ref.watch(homeLayoutProvider).visible)
                ..._section(context, k),
              const Padding(padding: AppSpacing.screen, child: _IdeaCard()),
            ],
          ),
        ),
      ),
    );
  }

  /// Bir opsiyonel ana-ekran bölümünün widget'larını döndürür (sıra/gizleme
  /// kullanıcı tercihine göre [homeLayoutProvider]'dan gelir).
  List<Widget> _section(BuildContext context, String key) {
    switch (key) {
      case 'storyRail':
        return const [StoryRail(), Gap.sm()];
      case 'greeting':
        return const [
          Padding(padding: AppSpacing.screen, child: _GreetingBanner()),
          Gap.md(),
        ];
      case 'religiousDay':
        return const [_ReligiousDayCard()];
      case 'gaugeCarousel':
        return const [
          Padding(padding: AppSpacing.screen, child: _GaugeCarousel()),
          Gap.md(),
        ];
      case 'prayerStrip':
        return [
          SectionHeader(title: 'home.todayPrayerTimes'.tr()),
          Padding(
            padding: AppSpacing.screen,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(Routes.imsakiye),
              child: const PrayerStrip(),
            ),
          ),
          const Gap.md(),
        ];
      case 'nearestMosque':
        return const [
          Padding(padding: AppSpacing.screen, child: _NearestMosqueCard()),
          Gap.lg(),
        ];
      case 'featured':
        return [
          SectionHeader(title: 'home.featured'.tr()),
          const Padding(padding: AppSpacing.screen, child: _FeaturedGrid()),
          Padding(
            padding: AppSpacing.screen,
            child: _SeeMoreButton(onTap: () => context.push(Routes.more)),
          ),
          const Gap.lg(),
        ];
      case 'quiz':
        return const [
          Padding(padding: AppSpacing.screen, child: _QuizCard()),
          Gap.lg(),
        ];
      case 'verseHadithPair':
        return const [_VerseHadithPair(), Gap.lg()];
      case 'mediaPair':
        return const [
          _MediaPair(),
          Gap.md(),
          Padding(padding: AppSpacing.screen, child: _DailyFact()),
          Gap.lg(),
        ];
      case 'verseOfDay':
        return const [
          Padding(padding: AppSpacing.screen, child: _VerseOfDayCard()),
          Gap.lg(),
        ];
      case 'hadithOfDay':
        return const [
          Padding(padding: AppSpacing.screen, child: _HadithOfDayCard()),
          Gap.lg(),
        ];
      case 'dailyDua':
        return const [
          Padding(padding: AppSpacing.screen, child: _DailyDuaCard()),
          Gap.lg(),
        ];
      case 'videos':
        return [
          SectionHeader(
            title: 'home.videos'.tr(),
            onSeeAll: () => context.push(Routes.feed),
          ),
          const _VideoRail(),
          const Gap.lg(),
        ];
      case 'quickPair':
        return const [
          Padding(padding: AppSpacing.screen, child: _QuickPair()),
          Gap.lg(),
        ];
      case 'wallpaper':
        return [
          SectionHeader(
            title: 'home.dailyWallpaper'.tr(),
            onSeeAll: () => context.push(Routes.wallpapers),
          ),
          const _DailyWallpaper(),
          const Gap.md(),
          // ⑳ Duvar kâğıtlarının altında kısa "Bunu biliyor muydun" (1-2 satır).
          const Padding(padding: AppSpacing.screen, child: _DailyFact()),
          const Gap.lg(),
        ];
      case 'widgetPromo':
        return const [
          Padding(padding: AppSpacing.screen, child: _WidgetPromoCard()),
          Gap.md(),
        ];
      default:
        return const [];
    }
  }
}

/// Öne Çıkanların hemen altında: Sesli Hikâyeler + Tebrik Kartı yan yana,
/// alt açıklamalı (hızlı erişim çifti).
class _QuickPair extends StatelessWidget {
  const _QuickPair();
  @override
  Widget build(BuildContext context) {
    // Tebrik Kartı + Dua Duvarı YAN YANA (kullanıcı 2026-06-18). IntrinsicHeight:
    // ListView'da yükseklik sınırsız olduğundan `stretch`li Row sıfıra çökerdi;
    // IntrinsicHeight iki kartı en uzunun boyuna eşitler (çökmez).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickCard(
              icon: AppIcons.card,
              title: 'greetings.title'.tr(),
              desc: 'xt.hmGreetingCardDesc'.tr(),
              onTap: () => context.push(Routes.greetings),
            ),
          ),
          const Gap.md(),
          Expanded(
            child: _QuickCard(
              icon: Icons.front_hand_rounded,
              title: 'duaWall.title'.tr(),
              desc: 'xt.hmDuaWallDesc'.tr(),
              onTap: () => context.push(Routes.duaWall),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: onTap,
      patterned: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.gold.withValues(alpha: 0.13),
            ),
            child: Icon(icon, color: c.gold, size: 20),
          ),
          const Gap.sm(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// Story çemberleri ile geri sayım arasındaki kişisel karşılama (kullanıcı
/// 2026-06-18). Girişliyse "Aleykümselam, {ad}"; misafirse "hoş geldin" + saate
/// göre hayırlı sabahlar/günler/akşamlar/geceler.
class _GreetingBanner extends ConsumerWidget {
  const _GreetingBanner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final name = (ref.watch(authControllerProvider).user?.name ?? '').trim();
    final h = (ref.watch(clockProvider).value ?? DateTime.now()).hour;
    final timeGreeting = h < 11
        ? 'xt.hmGoodMorning'.tr()
        : h < 17
            ? 'xt.hmGoodDay'.tr()
            : h < 21
                ? 'xt.hmGoodEvening'.tr()
                : 'xt.hmGoodNight'.tr();
    final night = h < 6 || h >= 19;
    final title = name.isNotEmpty
        ? 'xt.hmGreetingTitleNamed'.tr(args: [name])
        : 'xt.hmGreetingTitle'.tr();
    final sub = name.isNotEmpty
        ? 'xt.hmGreetingSubNamed'.tr(args: [timeGreeting])
        : 'xt.hmGreetingSubGuest'.tr(args: [timeGreeting]);
    return SelayaCard(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.gold.withValues(alpha: 0.14),
            ),
            child: Icon(
              night ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              color: c.gold,
              size: 18,
            ),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lang = context.langCode;
    final city = ref.watch(selectedCityProvider).value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        city?.name(lang) ?? 'SELAYA',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const Gap.xs(),
                    const Icon(
                      AppIcons.location,
                      size: 18,
                      color: AppColors.gold,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'home.appTagline'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: c.gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'home.fewAds'.tr(),
                        style: TextStyle(
                          color: c.gold,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap.md(),
          const _HeaderWeather(),
        ],
      ),
    );
  }
}

/// Weather in the header (icon + condition + temperature); tap for the 3-4 day
/// forecast. Replaced the old notification bell at the user's request.
class _HeaderWeather extends ConsumerWidget {
  const _HeaderWeather();

  void _showForecast(BuildContext context, List<WeatherDay> days) {
    final lang = context.langCode;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'home.weather'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Gap.md(),
              for (final d in days.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          DateFormat('EEEE', lang).format(d.date),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Icon(d.icon, color: context.colors.gold, size: 20),
                      const Gap.sm(),
                      Expanded(
                        child: Text(
                          d.labelKey().tr(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ),
                      Text(
                        '${d.tMax.round()}° / ${d.tMin.round()}°',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weatherForecastProvider);
    return async.maybeWhen(
      data: (days) {
        if (days.isEmpty) return const SizedBox.shrink();
        final c = context.colors;
        final today = days.first;
        return GestureDetector(
          onTap: () => _showForecast(context, days),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(today.icon, color: c.gold, size: 22),
                const SizedBox(width: 7),
                Text(
                  today.labelKey().tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(width: 8),
                Text(
                  '${today.tMax.round()}°',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Shown on the home screen when location permission hasn't been granted, so
/// prayer times may be wrong — taps through to city selection (PDF: warn on
/// app entry if setup isn't done). Dismissible.
class _LocationWarningBanner extends ConsumerStatefulWidget {
  const _LocationWarningBanner();
  @override
  ConsumerState<_LocationWarningBanner> createState() =>
      _LocationWarningBannerState();
}

class _LocationWarningBannerState
    extends ConsumerState<_LocationWarningBanner> {
  bool _granted = true; // assume ok until checked, to avoid a flash
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final g = await ref.read(permissionServiceProvider).locationGranted();
    if (mounted) setState(() => _granted = g);
  }

  @override
  Widget build(BuildContext context) {
    if (_granted || _dismissed) return const SizedBox.shrink();
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        0,
      ),
      child: SelayaCard(
        onTap: () => context.push(Routes.citySelect),
        gradient: LinearGradient(
          colors: [c.gold.withValues(alpha: 0.22), c.surfaceAlt],
        ),
        child: Row(
          children: [
            const Icon(AppIcons.location, color: AppColors.gold, size: 22),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'onboarding.locationWarnTitle'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'onboarding.locationWarnBody'.tr(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(AppIcons.close, size: 18, color: c.textTertiary),
              onPressed: () => setState(() => _dismissed = true),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Günün Ayeti" / "Günün Hadisi" ortak okunur kartı — Arapça + meal + kaynak +
/// beğeni + paylaş.
class _DailyContentCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? arabic;
  final String text;
  final String reference;
  final String likeKey;
  final String backgroundImage;
  const _DailyContentCard({
    required this.label,
    required this.icon,
    required this.text,
    required this.reference,
    required this.likeKey,
    required this.backgroundImage,
    this.arabic,
  });

  @override
  Widget build(BuildContext context) {
    // Arka plan = panel duvar kâğıtlarından biri (kart + paylaşım aynı görsel).
    return ClipRRect(
      borderRadius: AppRadius.rXl,
      child: Stack(
        children: [
          Positioned.fill(child: AppImage.cdn(backgroundImage)),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x9905070D), Color(0xF205070D)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: AppColors.goldBright),
                    const SizedBox(width: 6),
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.goldBright,
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (arabic != null && arabic!.isNotEmpty) ...[
                  const Gap.md(),
                  Text(
                    arabic!,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.arabic(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
                const Gap.md(),
                Text(
                  '"$text"',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const Gap.sm(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reference,
                        style: const TextStyle(
                          color: AppColors.goldBright,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    LikeButton(likeKey: likeKey, light: true),
                    const Gap.xs(),
                    GestureDetector(
                      onTap: () => showVerseShareSheet(
                        context,
                        arabic: arabic,
                        text: text,
                        reference: reference,
                        label: label,
                        backgroundImage: backgroundImage,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: AppRadius.rSm,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              AppIcons.share,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'common.share'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseOfDayCard extends ConsumerWidget {
  const _VerseOfDayCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final all =
        ref.watch(inspirationProvider).value ?? const <InspirationItem>[];
    // Sadece gerçek ayetler (Arapçası olanlar) — paneldeki bozuk/başlık-yerine
    // dosya-adı içeren öğeler "Günün Ayeti"ne düşmesin.
    final verses = [
      for (final i in all)
        if (i.type == 'verse' && i.arabic.isNotEmpty) i,
    ];
    if (verses.isEmpty) return const SizedBox.shrink();
    final v = verses[DateTime.now().day % verses.length];
    final seed = ref.watch(inspirationSeedProvider);
    final wps = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];
    return _DailyContentCard(
      label: 'akis.verseOfDay'.tr(),
      icon: Icons.menu_book_rounded,
      arabic: v.arabic,
      text: v.text(lang),
      reference: v.reference,
      likeKey: 'verse:${v.id}',
      backgroundImage: wps.isEmpty ? '' : wps[(seed + 2) % wps.length].image,
    );
  }
}

class _HadithOfDayCard extends ConsumerWidget {
  const _HadithOfDayCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final hadiths = ref.watch(hadithsProvider).value ?? const <Hadith>[];
    if (hadiths.isEmpty) return const SizedBox.shrink();
    final h = hadiths[DateTime.now().day % hadiths.length];
    final seed = ref.watch(inspirationSeedProvider);
    final wps = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];
    return _DailyContentCard(
      label: 'akis.hadithOfDay'.tr(),
      icon: Icons.format_quote_rounded,
      arabic: h.arabic,
      text: h.text(lang),
      reference: h.collection,
      likeKey: 'hadith:${h.id}',
      backgroundImage: wps.isEmpty ? '' : wps[(seed + 3) % wps.length].image,
    );
  }
}

/// "Günün Duası" — gerçek dualar (Dualar ekranıyla aynı kaynak: duasProvider),
/// her açılışta rastgele biri, duvar kâğıdı arkaplanlı.
class _DailyDuaCard extends ConsumerWidget {
  const _DailyDuaCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final duas = ref.watch(duasProvider).value ?? const <Dua>[];
    if (duas.isEmpty) return const SizedBox.shrink();
    final seed = ref.watch(inspirationSeedProvider);
    final d = duas[seed % duas.length];
    final wps = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];
    return GestureDetector(
      onTap: () => context.push('${Routes.duas}?open=${d.id}'),
      child: _DailyContentCard(
        label: 'akis.duaOfDay'.tr(),
        icon: Icons.volunteer_activism_rounded,
        // Arapça KALDIRILDI (kullanıcı 2026-06-18: tıklayınca zaten açılıyor).
        text: d.text(lang),
        reference: d.title(lang),
        likeKey: 'dua:${d.id}',
        backgroundImage: wps.isEmpty ? '' : wps[(seed + 1) % wps.length].image,
      ),
    );
  }
}

/// Günün Ayeti + Günün Hadisi YAN YANA — kompakt, Arapçasız (kullanıcı
/// 2026-06-18: "yan yana, arapçaya gerek yok, tıklayınca açılıyor"). Dokun → liste.
class _VerseHadithPair extends ConsumerWidget {
  const _VerseHadithPair();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final seed = ref.watch(inspirationSeedProvider);
    final wps = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];
    final all =
        ref.watch(inspirationProvider).value ?? const <InspirationItem>[];
    final verses = [
      for (final i in all)
        if (i.type == 'verse' && i.arabic.isNotEmpty) i,
    ];
    // Hadis de inspirationProvider'dan (Hadisler liste ekranıyla AYNI kaynak →
    // ?open=id eşleşir, popup açılır); hadithsProvider FARKLI ID'ler içerir.
    final hadiths = [for (final i in all) if (i.type == 'hadith') i];

    final cards = <Widget>[];
    if (verses.isNotEmpty) {
      final v = verses[DateTime.now().day % verses.length];
      cards.add(_MiniContentCard(
        label: 'akis.verseOfDay'.tr(),
        icon: Icons.menu_book_rounded,
        text: v.text(lang),
        reference: v.reference,
        backgroundImage: wps.isEmpty ? '' : wps[(seed + 2) % wps.length].image,
        onTap: () => context.push('${Routes.verses}?open=${v.id}'),
      ));
    }
    if (hadiths.isNotEmpty) {
      final h = hadiths[DateTime.now().day % hadiths.length];
      cards.add(_MiniContentCard(
        label: 'akis.hadithOfDay'.tr(),
        icon: Icons.format_quote_rounded,
        text: h.text(lang),
        reference: h.reference,
        backgroundImage: wps.isEmpty ? '' : wps[(seed + 3) % wps.length].image,
        onTap: () => context.push('${Routes.hadiths}?open=${h.id}'),
      ));
    }
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: AppSpacing.screen,
      child: SizedBox(
        height: 178,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, w) in cards.indexed) ...[
              if (i > 0) const Gap.md(),
              Expanded(child: w),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kompakt günlük içerik kartı (ayet/hadis çifti için): görsel zemin + etiket +
/// kısa metin + kaynak. Arapça/paylaş yok; dokun → ilgili liste.
class _MiniContentCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String text;
  final String reference;
  final String backgroundImage;
  final VoidCallback onTap;
  const _MiniContentCard({
    required this.label,
    required this.icon,
    required this.text,
    required this.reference,
    required this.backgroundImage,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadius.rXl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            backgroundImage.isEmpty
                ? const ColoredBox(color: Color(0xFF0E1322))
                : AppImage.cdn(backgroundImage),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x9905070D), Color(0xF205070D)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 13, color: AppColors.goldBright),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.goldBright,
                            fontSize: 10,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '"$text"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const Gap.xs(),
                  Text(
                    reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.goldBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Videolar + Günün Duvar Kâğıdı YAN YANA (kullanıcı 2026-06-18).
class _MediaPair extends ConsumerWidget {
  const _MediaPair();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider).value ?? const <FeedItem>[];
    final wps = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];

    final tiles = <Widget>[];
    if (feed.isNotEmpty) {
      final v = feed[DateTime.now().day % feed.length];
      tiles.add(_MediaTile(
        label: 'home.videos'.tr(),
        play: true,
        onTap: () => context.push(Routes.feed),
        image: v.poster.isNotEmpty
            ? AppImage.cdn(v.poster)
            : ref.watch(videoThumbProvider(v.video)).maybeWhen(
                  data: (p) => p == null
                      ? const _VideoPosterPlaceholder()
                      : Image.file(File(p), fit: BoxFit.cover),
                  orElse: () => const _VideoPosterPlaceholder(),
                ),
      ));
    }
    if (wps.isNotEmpty) {
      final wp = wps[DateTime.now().day % wps.length];
      tiles.add(_MediaTile(
        label: 'home.dailyWallpaper'.tr(),
        play: false,
        onTap: () => context.push(Routes.wallpapers),
        image: AppImage.cdn(wp.image),
      ));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: AppSpacing.screen,
      child: SizedBox(
        height: 200,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, t) in tiles.indexed) ...[
              if (i > 0) const Gap.md(),
              Expanded(child: t),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final String label;
  final Widget image;
  final bool play;
  final VoidCallback onTap;
  const _MediaTile({
    required this.label,
    required this.image,
    required this.play,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadius.rXl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22000000), Color(0xCC05070D)],
                ),
              ),
            ),
            if (play)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.40),
                  ),
                  child: const Icon(AppIcons.play, color: Colors.white, size: 24),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoRail extends ConsumerWidget {
  const _VideoRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(feedProvider).value ?? const <FeedItem>[];
    if (list.isEmpty) return const SizedBox.shrink();
    // Slider KALDIRILDI (kullanıcı 2026-06-15: "slider mantığını kaldır, 1 tane
    // görünsün, tıklayınca o sayfaya gitsin") → tek "günün videosu"; dokun → Akış.
    final v = list[DateTime.now().day % list.length];
    return Padding(
      padding: AppSpacing.screen,
      child: SizedBox(
        height: 190,
        child: GestureDetector(
          onTap: () => context.push(Routes.feed),
          child: ClipRRect(
            borderRadius: AppRadius.rXl,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (v.poster.isNotEmpty)
                  AppImage.cdn(v.poster)
                else
                  ref
                      .watch(videoThumbProvider(v.video))
                      .maybeWhen(
                        data: (p) => p == null
                            ? const _VideoPosterPlaceholder()
                            : Image.file(File(p), fit: BoxFit.cover),
                        orElse: () => const _VideoPosterPlaceholder(),
                      ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22000000), Color(0xDD000000)],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.40),
                    ),
                    child: const Icon(
                      AppIcons.play,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 6,
                  bottom: 8,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          v.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      LikeButton(likeKey: 'feed:${v.id}', light: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Poster'ı olmayan videonun kapağı: markaya uygun koyu-altın degrade + silik
/// video ikonu (oynat düğmesi/yazar/beğeni üst katmanda zaten var).
class _VideoPosterPlaceholder extends StatelessWidget {
  const _VideoPosterPlaceholder();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.goldDeep.withValues(alpha: 0.40), c.surfaceAlt, c.bg],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.85, -0.8),
        child: Icon(
          Icons.video_library_rounded,
          size: 40,
          color: c.gold.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

// _AiCard (SELAYA AI Asistanı promo kartı) KALDIRILDI — AI asistanı komple
// çıkarıldı (kullanıcı 2026-06-23).
// _AudioStoriesCard (Sesli Hikâyeler promo kartı) KALDIRILDI — sesli hikâye
// özelliği komple çıkarıldı (kullanıcı 2026-06-15).

class _DailyWallpaper extends ConsumerWidget {
  const _DailyWallpaper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final list = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];
    if (list.isEmpty) return const SizedBox(height: 0);
    // Slider KALDIRILDI (kullanıcı 2026-06-15: "slider mantığını kaldır, 1 tane
    // görünsün, tıklayınca o sayfaya gitsin") → tek "günün duvar kâğıdı"; dokun
    // → Duvar Kâğıtları.
    final wp = list[DateTime.now().day % list.length];
    return Padding(
      padding: AppSpacing.screen,
      child: SizedBox(
        height: 190,
        child: GestureDetector(
          onTap: () => context.push(Routes.wallpapers),
          child: ClipRRect(
            borderRadius: AppRadius.rXl,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage.cdn(wp.image),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC05070D)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      wp.title(lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kullanıcının seçtiği/sıraladığı araçlardan oluşan "Öne Çıkanlar" ızgarası
/// (içerik `featuredToolsProvider`'dan; "Öne Çıkanlar İçeriği" ekranından yönetilir).
class _FeaturedGrid extends ConsumerWidget {
  const _FeaturedGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(featuredToolsProvider).visible;
    // Cells grow taller with the user's font scale so labels never overflow.
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.45);
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.80 / scale,
      children: [
        for (final (i, key) in keys.indexed)
          if (featuredTools[key] != null)
            SelayaCard(
              onTap: () => context.push(featuredTools[key]!.route),
              borderRadius: AppRadius.rMd,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FeatureIcon(
                    featuredTools[key]!.icon,
                    index: i,
                    size: 19,
                    padding: 9,
                  ),
                  const Gap.xs(),
                  Flexible(
                    child: Text(
                      featuredTools[key]!.labelKey.tr(),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Küçük "Daha Fazla" linki — Öne Çıkanlar altında, tüm araçlara (more) gider.
class _SeeMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeMoreButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'common.more'.tr(),
              style: TextStyle(color: c.gold, fontWeight: FontWeight.w700),
            ),
            const Gap.xs(),
            Icon(Icons.arrow_forward_rounded, size: 16, color: c.gold),
          ],
        ),
      ),
    );
  }
}

/// Swipeable gauge: page 0 = next-prayer countdown card, page 1 = 24h radial
/// dial — matching the PDF's "swipe to change the indicator" request.
class _GaugeCarousel extends StatefulWidget {
  const _GaugeCarousel();
  @override
  State<_GaugeCarousel> createState() => _GaugeCarouselState();
}

class _GaugeCarouselState extends State<_GaugeCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        SizedBox(
          // Kompakt — geri sayım kartının üst/alt boşluğu en aza indirildi. Büyük
          // fontta (1.3x) içerik taşmasın diye yükseklik metin ölçeğiyle büyür.
          height:
              218.0 *
              MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.35),
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: const [
              Center(child: NextPrayerCard()),
              Center(child: PrayerClockDial()),
              Center(child: PrayerTimelineGauge()),
            ],
          ),
        ),
        const Gap.sm(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i ? c.gold : c.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// "Add SELAYA to your home screen" promo (replaces the old premium upsell).
class _WidgetPromoCard extends StatelessWidget {
  const _WidgetPromoCard();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: () => context.push(Routes.widgetsGallery),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.gold.withValues(alpha: 0.14),
            ),
            child: Icon(AppIcons.tune, color: c.gold, size: 22),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home.addWidgetTitle'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'home.addWidgetDesc'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          Icon(AppIcons.forward, size: 16, color: c.textTertiary),
        ],
      ),
    );
  }
}

/// ⑳ Anasayfada duvar kâğıtlarının altında kısa bir günlük bilgi (1-2 satır,
/// güne göre döner). Akış'taki "Bunu biliyor muydun"un küçük anasayfa hâli.
/// Ana ekran "Bilgi Yarışması" kartı — puan/seri özeti + yarışmaya yönlendirir.
class _QuizCard extends ConsumerWidget {
  const _QuizCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final stats = ref.watch(quizStatsProvider);
    final sub = stats.points > 0
        ? '${stats.points} ${'quiz.points'.tr()} · 🔥 ${stats.streak}'
        : 'quiz.homeCta'.tr();
    return SelayaCard(
      onTap: () => context.push(Routes.quiz),
      borderRadius: AppRadius.rLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [c.gold, c.goldBright]),
          ),
          child: Icon(Icons.quiz_rounded, color: c.bg, size: 20),
        ),
        const Gap.base(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('quiz.title'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Icon(AppIcons.forward, color: c.gold),
      ]),
    );
  }
}

class _DailyFact extends StatelessWidget {
  const _DailyFact();
  static const _facts = <(String, String)>[
    (
      "Kur'an'da 114 sûre ve 6236 âyet bulunur.",
      'The Quran contains 114 surahs and 6236 verses.',
    ),
    (
      "Esmâ-ül Hüsnâ, Allah'ın 99 güzel ismidir.",
      'Asma al-Husna are the 99 Beautiful Names of Allah.',
    ),
    (
      'Tebessüm sadakadır; küçük iyilikler büyük sevaplara vesiledir.',
      'A smile is charity; small kindnesses bring great rewards.',
    ),
    (
      'Cuma günü müminlerin haftalık bayramı sayılır.',
      'Friday is the weekly festival of the believers.',
    ),
    (
      "Bir âyet bile olsa her gün Kur'an okumak kalbi diri tutar.",
      'Reading even one verse of the Quran daily keeps the heart alive.',
    ),
    (
      'Sabah ve akşam zikirleri günü manevi korumayla çevreler.',
      'Morning and evening adhkar surround the day with protection.',
    ),
    (
      'İlk vahiy "Oku!" emriyle Hira Mağarası\'nda gelmiştir.',
      'The first revelation began with "Read!" in the Cave of Hira.',
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isTr = context.langCode == 'tr';
    final f = _facts[DateTime.now().day % _facts.length];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.gold.withValues(alpha: 0.07),
        borderRadius: AppRadius.rLg,
        border: Border.all(color: c.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: c.gold, size: 20),
          const Gap.md(),
          Expanded(
            child: Text(
              '${'xt.hmDidYouKnow'.tr()} ${isTr ? f.$1 : f.$2}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Help us improve — share your idea" card → opens the user's mail client.
class _IdeaCard extends StatelessWidget {
  const _IdeaCard();

  Future<void> _shareIdea() async {
    final subject = Uri.encodeComponent('SELAYA — Görüş & Öneri / Feedback');
    final body = Uri.encodeComponent('Görüşünüz / Your idea:\n');
    final uri = Uri.parse(
      'mailto:contact@selaya.app?subject=$subject&body=$body',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      gradient: LinearGradient(
        colors: [c.gold.withValues(alpha: 0.14), c.surfaceAlt],
      ),
      onTap: _shareIdea,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.gold.withValues(alpha: 0.18),
            ),
            child: Icon(AppIcons.sparkles, color: c.gold, size: 22),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home.shareIdeaTitle'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: c.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'home.shareIdeaDesc'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          Icon(AppIcons.forward, size: 16, color: c.textTertiary),
        ],
      ),
    );
  }
}

/// Shows today's religious day (with day index for multi-day feasts) if active.
class _ReligiousDayCard extends ConsumerWidget {
  const _ReligiousDayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeReligiousDayProvider).value;
    if (active == null) return const SizedBox.shrink();
    final c = context.colors;
    final lang = context.langCode;
    final day = active.day;
    final isHoliday = day.type == 'holiday';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        0,
        AppSpacing.base,
        AppSpacing.md,
      ),
      child: SelayaCard(
        onTap: () => context.push(Routes.calendar),
        gradient: LinearGradient(
          colors: [c.gold.withValues(alpha: 0.26), c.surfaceAlt],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.gold.withValues(alpha: 0.18),
              ),
              child: Icon(
                isHoliday ? AppIcons.mosque : AppIcons.moon,
                color: c.gold,
                size: 22,
              ),
            ),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          day.name(lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: c.gold,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (day.isMultiDay) ...[
                        const Gap.sm(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.gold,
                            borderRadius: AppRadius.rSm,
                          ),
                          child: Text(
                            'calendar.nthDay'.tr(args: ['${active.index}']),
                            style: TextStyle(
                              color: c.onGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Gap.xxs(),
                  Text(
                    '${formatGregorian(DateTime.now(), lang)} • ${day.hijri}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(AppIcons.forward, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}

String _mosqueDist(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

Future<void> _openMosqueDirections(double lat, double lng) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
  );
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Two-line "nearest mosque" card (name + distance · directions) on the home
/// feed. Reads the session-cached [nearestMosqueProvider] (GPS + OpenStreetMap);
/// shows a slim "searching…" state while it resolves and hides entirely if
/// location is unavailable or nothing is found. Tapping opens Maps directions.
class _NearestMosqueCard extends ConsumerWidget {
  const _NearestMosqueCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return ref
        .watch(nearestMosqueProvider)
        .when(
          loading: () => SelayaCard(
            child: Row(
              children: [
                _iconBadge(c),
                const Gap.md(),
                Expanded(
                  child: Text(
                    'home.nearestMosqueFinding'.tr(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
                  ),
                ),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.gold,
                  ),
                ),
              ],
            ),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (m) {
            if (m == null) return const SizedBox.shrink();
            return SelayaCard(
              onTap: () => _openMosqueDirections(m.lat, m.lng),
              child: Row(
                children: [
                  _iconBadge(c),
                  const Gap.md(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'home.nearestMosque'.tr(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: c.textTertiary),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Gap.xxs(),
                        Row(
                          children: [
                            Icon(AppIcons.location, size: 13, color: c.gold),
                            const SizedBox(width: 3),
                            Text(
                              _mosqueDist(m.distanceKm),
                              style: Theme.of(
                                context,
                              ).textTheme.labelMedium?.copyWith(color: c.gold),
                            ),
                            Text(
                              '  ·  ${'mosques.directions'.tr()}',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: c.textTertiary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.gold.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.directions_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
                  ),
                ],
              ),
            );
          },
        );
  }

  Widget _iconBadge(SelayaColors c) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c.gold.withValues(alpha: 0.12),
    ),
    child: const Icon(AppIcons.mosque, color: AppColors.gold, size: 20),
  );
}
