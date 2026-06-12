import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
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
import '../../../core/widgets/animated_ai_icon.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/feature_icon.dart';
import '../../../core/widgets/like_button.dart';
import '../../../core/widgets/geometric_background.dart';
import '../../../core/widgets/mini_player_chrome.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../daily_tasks/data/daily_tasks_controller.dart';
import '../../daily_tasks/domain/daily_task.dart';
import '../../social_feed/data/video_thumbs.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../ibadah_tracking/data/prayer_checkin.dart';
import '../../prayer_times/presentation/widgets/next_prayer_card.dart';
import '../../prayer_times/presentation/widgets/prayer_clock_dial.dart';
import '../../prayer_times/presentation/widgets/prayer_strip.dart';
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
    // After a fard prayer's time passes, ask once (on the next home open)
    // whether it was prayed → logs to İbadet Takibi (#4).
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPrayerCheckIn());
  }

  Future<void> _askPrayerCheckIn() async {
    final slot = await pendingPrayerCheckIn(ref);
    if (slot == null || !mounted || !context.mounted) return;
    await showPrayerCheckIn(context, ref, slot);
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
              const Padding(
                padding: AppSpacing.screen,
                child: _IdeaCard(),
              ),
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
      case 'religiousDay':
        return const [_ReligiousDayCard()];
      case 'gaugeCarousel':
        return const [
          Padding(padding: AppSpacing.screen, child: _GaugeCarousel()),
          Gap.md(),
        ];
      case 'prayerStrip':
        return [
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
      case 'dailyTasks':
        return [
          SectionHeader(title: 'tasks.title'.tr()),
          const Padding(padding: AppSpacing.screen, child: _DailyTasksCard()),
          const Gap.lg(),
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
      case 'ai':
        return const [
          Padding(padding: AppSpacing.screen, child: _AiCard()),
          Gap.md(),
        ];
      case 'quickPair':
        return const [
          Padding(padding: AppSpacing.screen, child: _QuickPair()),
          Gap.lg(),
        ];
      case 'audioStories':
        return const [
          Padding(padding: AppSpacing.screen, child: _AudioStoriesCard()),
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
    final isTr = context.langCode == 'tr';
    // NOT: stretch / IntrinsicHeight KULLANILMAZ — patterned SelayaCard içindeki
    // Stack, intrinsic yükseklik sorgusunda çöküp tüm ana ekranı boşaltır.
    return Row(
      children: [
        Expanded(
          child: _QuickCard(
            icon: AppIcons.headphones,
            title: 'audioStories.title'.tr(),
            desc: isTr
                ? 'Huzur veren İslami hikâyeler'
                : 'Soothing Islamic stories',
            onTap: () => context.push(Routes.audioStories),
          ),
        ),
        const Gap.md(),
        Expanded(
          child: _QuickCard(
            icon: AppIcons.card,
            title: 'greetings.title'.tr(),
            desc: isTr
                ? 'Sevdiklerine özel kartlar'
                : 'Special cards for loved ones',
            onTap: () => context.push(Routes.greetings),
          ),
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;
  const _QuickCard(
      {required this.icon,
      required this.title,
      required this.desc,
      required this.onTap});
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
                shape: BoxShape.circle, color: c.gold.withValues(alpha: 0.13)),
            child: Icon(icon, color: c.gold, size: 20),
          ),
          const Gap.sm(),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: c.textSecondary, fontSize: 12, height: 1.3)),
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
          AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(city?.name(lang) ?? 'SELAYA',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    const SizedBox(width: 4),
                    const Icon(AppIcons.location, size: 18, color: AppColors.gold),
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text('home.appTagline'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: c.textSecondary)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: c.gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('home.fewAds'.tr(),
                          style: TextStyle(
                              color: c.gold,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
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
              Text('home.weather'.tr(),
                  style: Theme.of(context).textTheme.titleMedium),
              const Gap.md(),
              for (final d in days.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 96,
                          child: Text(DateFormat('EEEE', lang).format(d.date),
                              style: Theme.of(context).textTheme.bodyMedium)),
                      Icon(d.icon, color: context.colors.gold, size: 20),
                      const Gap.sm(),
                      Expanded(
                        child: Text(d.labelKey().tr(),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: context.colors.textSecondary)),
                      ),
                      Text('${d.tMax.round()}° / ${d.tMin.round()}°',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Text(today.labelKey().tr(),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.textSecondary)),
                const SizedBox(width: 8),
                Text('${today.tMax.round()}°',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
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
          AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      child: SelayaCard(
        onTap: () => context.push(Routes.citySelect),
        gradient: LinearGradient(
            colors: [c.gold.withValues(alpha: 0.22), c.surfaceAlt]),
        child: Row(
          children: [
            const Icon(AppIcons.location, color: AppColors.gold, size: 22),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('onboarding.locationWarnTitle'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text('onboarding.locationWarnBody'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textSecondary)),
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

/// Ana ekran günlük görev kartı — ilerleme halkası + seri + sıradaki 2 görev.
class _DailyTasksCard extends ConsumerWidget {
  const _DailyTasksCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lang = context.langCode;
    final tasks = dailyTasksFor(DateTime.now());
    final log = ref.watch(dailyTasksProvider);
    final done =
        log[DailyTasksController.dateKey(DateTime.now())] ?? const <String>[];
    final stats = ref.watch(taskStatsProvider);
    final ratio = dailyTaskCount == 0 ? 0.0 : stats.todayDone / dailyTaskCount;
    final pending =
        tasks.where((t) => !done.contains(t.id)).take(3).toList();
    return SelayaCard(
      onTap: () => context.push(Routes.tasks),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 5,
                        backgroundColor: c.border,
                        valueColor: AlwaysStoppedAnimation(c.gold),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text('${stats.todayDone}/$dailyTaskCount',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 11)),
                  ],
                ),
              ),
              const Gap.md(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('tasks.today'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded,
                            size: 15,
                            color: stats.streak > 0 ? c.gold : c.textTertiary),
                        const SizedBox(width: 3),
                        Text('tasks.streak'.tr(args: ['${stats.streak}']),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textTertiary),
            ],
          ),
          if (pending.isNotEmpty) ...[
            const Gap.sm(),
            Divider(height: 1, color: c.border),
            const Gap.sm(),
            for (final t in pending)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(t.icon, size: 18, color: c.gold),
                    const Gap.sm(),
                    Expanded(
                      child: Text(t.title(lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ],
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
          // memWidth: degrade altındaki dekoratif arka plan — tam çözünürlük
          // decode etmek RAM/jank israfı (perf turu 2).
          Positioned.fill(child: AppImage.cdn(backgroundImage, memWidth: 720)),
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
                    Text(label.toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.goldBright,
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                if (arabic != null && arabic!.isNotEmpty) ...[
                  const Gap.md(),
                  Text(arabic!,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTypography.arabic(fontSize: 20, color: Colors.white)),
                ],
                const Gap.md(),
                Text('"$text"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.45)),
                const Gap.sm(),
                Row(
                  children: [
                    Expanded(
                      child: Text(reference,
                          style: const TextStyle(
                              color: AppColors.goldBright,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    LikeButton(likeKey: likeKey, light: true),
                    const SizedBox(width: 4),
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
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: AppRadius.rSm,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(AppIcons.share,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('common.share'.tr(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
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
        if (i.type == 'verse' && i.arabic.isNotEmpty) i
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
      onTap: () => context.push(Routes.duas),
      child: _DailyContentCard(
        label: 'akis.duaOfDay'.tr(),
        icon: Icons.volunteer_activism_rounded,
        arabic: d.arabic,
        text: d.text(lang),
        reference: d.title(lang),
        likeKey: 'dua:${d.id}',
        backgroundImage: wps.isEmpty ? '' : wps[(seed + 1) % wps.length].image,
      ),
    );
  }
}

/// Tam genişlikte kayan (slider) video önizlemesi; her kart videonun kapak
/// görselini gösterir (panel kapağı yoksa paketteki bir arka plana düşer),
/// dokununca tam ekran akışı açar.
/// Otomatik geçen, ortadaki öğesi büyük 3'lü vitrin (story gibi). Videolar ve
/// duvar kâğıtları aynı sistemi paylaşır: ~4 sn'de bir kayar, elle kaydırınca
/// sayaç sıfırlanır; merkez kart tam boy, komşular hafifçe küçülüp soluklaşır.
class _AutoCarousel extends StatefulWidget {
  final int itemCount;
  final double height;
  final Widget Function(BuildContext, int) builder;
  const _AutoCarousel({
    required this.itemCount,
    required this.height,
    required this.builder,
  });
  @override
  State<_AutoCarousel> createState() => _AutoCarouselState();
}

class _AutoCarouselState extends State<_AutoCarousel> {
  late final PageController _pc;
  Timer? _timer;
  double _page = 0;
  ValueListenable<bool>? _tickerMode;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 0.74)
      ..addListener(() {
        if (_pc.hasClients && _pc.page != null) {
          setState(() => _page = _pc.page!);
        }
      });
    _start();
  }

  // PERF: ekran görünmezken (başka sekme / üstte tam sayfa) 4 sn'lik otomatik
  // dönüş timer'ı DURUR — eskiden arka planda da kayma animasyonu tetikleyip
  // boşuna frame ürettiriyordu; görünür olunca kaldığı yerden devam eder.
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
    if (!mounted) return;
    if (_tickerMode?.value ?? true) {
      if (_timer == null) _start();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = null;
    if (widget.itemCount <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pc.hasClients) return;
      final next = ((_pc.page ?? 0).round() + 1) % widget.itemCount;
      _pc.animateToPage(next,
          duration: const Duration(milliseconds: 550), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_onTickerModeChanged);
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          // Kullanıcı parmağıyla kaydırınca otomatik sayacı yeniden başlat.
          if (n is UserScrollNotification) _start();
          return false;
        },
        child: PageView.builder(
          controller: _pc,
          itemCount: widget.itemCount,
          itemBuilder: (context, i) {
            final delta = (_page - i).abs().clamp(0.0, 1.0);
            final scale = 1.0 - delta * 0.16; // merkez 1.0 · komşu ~0.84
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: 1.0 - delta * 0.4,
                child: widget.builder(context, i),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VideoRail extends ConsumerWidget {
  const _VideoRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Vitrin: yalnızca İLK 12 video (5000 videoda carousel/thumb üretimi
    // patlamasın); tamamı Akış ekranında zaten kayarak geziliyor.
    final list = (ref.watch(feedProvider).value ?? const <FeedItem>[])
        .take(12)
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return _AutoCarousel(
      height: 210,
      itemCount: list.length,
      builder: (context, i) {
        final v = list[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: GestureDetector(
            onTap: () => context.push(Routes.feed, extra: i),
            child: ClipRRect(
              borderRadius: AppRadius.rXl,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Kapak: videonun KENDİ poster'ı; yoksa videonun KENDİ
                  // karesinden üretilen thumbnail (native, cache'li); o da
                  // yoksa nötr degrade. Duvar kâğıdından ÇEKİLMEZ.
                  if (v.poster.isNotEmpty)
                    AppImage.cdn(v.poster, memWidth: 800)
                  else
                    ref.watch(videoThumbProvider(v.video)).maybeWhen(
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
                      child: const Icon(AppIcons.play,
                          color: Colors.white, size: 28),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 6,
                    bottom: 8,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(v.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                        LikeButton(likeKey: 'feed:${v.id}', light: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          colors: [
            c.goldDeep.withValues(alpha: 0.40),
            c.surfaceAlt,
            c.bg,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.85, -0.8),
        child: Icon(Icons.video_library_rounded,
            size: 40, color: c.gold.withValues(alpha: 0.22)),
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: () => context.push(Routes.ai),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.rXl,
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Icon(AppIcons.sparkles,
                  size: 120, color: c.gold.withValues(alpha: 0.12)),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [c.gold, c.goldBright]),
                    ),
                    child: AnimatedAiIcon(color: c.bg, size: 26),
                  ),
                  const Gap.base(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('home.askSelayaTitle'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('home.askSelayaDesc'.tr(),
                            style:
                                TextStyle(color: c.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(AppIcons.forward, color: c.textTertiary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Sesli Hikâyeler" promo card on the home feed → opens the audio stories list.
class _AudioStoriesCard extends StatelessWidget {
  const _AudioStoriesCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: () => context.push(Routes.audioStories),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: c.gold.withValues(alpha: 0.14)),
            child: Icon(AppIcons.headphones, color: c.gold, size: 22),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('audioStories.title'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('home.audioStoriesDesc'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          Icon(AppIcons.forward, size: 16, color: c.textTertiary),
        ],
      ),
    );
  }
}

class _DailyWallpaper extends ConsumerWidget {
  const _DailyWallpaper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final list = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];
    if (list.isEmpty) return const SizedBox(height: 180);
    final items = list.take(12).toList();
    return _AutoCarousel(
      height: 200,
      itemCount: items.length,
      builder: (context, i) {
        final wp = items[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: GestureDetector(
            onTap: () => context.push(Routes.wallpapers),
            child: ClipRRect(
              borderRadius: AppRadius.rXl,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage.cdn(wp.image, memWidth: 540),
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
                      child: Text(wp.title(lang),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
              onTap: () => openRoute(context, featuredTools[key]!.route),
              borderRadius: AppRadius.rMd,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FeatureIcon(featuredTools[key]!.icon,
                      index: i, size: 19, padding: 9),
                  const Gap.xs(),
                  Flexible(
                    child: Text(featuredTools[key]!.labelKey.tr(),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall),
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
            Text('common.more'.tr(),
                style: TextStyle(color: c.gold, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
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
          // Kompakt — geri sayım kartının üst/alt boşluğu en aza indirildi.
          height: 218,
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
                shape: BoxShape.circle, color: c.gold.withValues(alpha: 0.14)),
            child: Icon(AppIcons.tune, color: c.gold, size: 22),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('home.addWidgetTitle'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('home.addWidgetDesc'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary)),
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
class _DailyFact extends StatelessWidget {
  const _DailyFact();
  static const _facts = <(String, String)>[
    ("Kur'an'da 114 sûre ve 6236 âyet bulunur.",
        'The Quran contains 114 surahs and 6236 verses.'),
    ("Esmâ-ül Hüsnâ, Allah'ın 99 güzel ismidir.",
        'Asma al-Husna are the 99 Beautiful Names of Allah.'),
    ('Tebessüm sadakadır; küçük iyilikler büyük sevaplara vesiledir.',
        'A smile is charity; small kindnesses bring great rewards.'),
    ('Cuma günü müminlerin haftalık bayramı sayılır.',
        'Friday is the weekly festival of the believers.'),
    ("Bir âyet bile olsa her gün Kur'an okumak kalbi diri tutar.",
        'Reading even one verse of the Quran daily keeps the heart alive.'),
    ('Sabah ve akşam zikirleri günü manevi korumayla çevreler.',
        'Morning and evening adhkar surround the day with protection.'),
    ('İlk vahiy "Oku!" emriyle Hira Mağarası\'nda gelmiştir.',
        'The first revelation began with "Read!" in the Cave of Hira.'),
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
            child: Text('${isTr ? 'Bunu biliyor muydun?' : 'Did you know?'} ${isTr ? f.$1 : f.$2}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.textSecondary, height: 1.4)),
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
    final uri = Uri.parse(
        'mailto:destek@selayaapp.com?subject=${Uri.encodeComponent('SELAYA — Görüş & Öneri')}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      gradient: LinearGradient(colors: [
        c.gold.withValues(alpha: 0.14),
        c.surfaceAlt,
      ]),
      onTap: _shareIdea,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: c.gold.withValues(alpha: 0.18)),
            child: Icon(AppIcons.sparkles, color: c.gold, size: 22),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('home.shareIdeaTitle'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: c.gold, fontWeight: FontWeight.w700)),
                Text('home.shareIdeaDesc'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary)),
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
          AppSpacing.base, 0, AppSpacing.base, AppSpacing.md),
      child: SelayaCard(
        onTap: () => context.push(Routes.calendar),
        gradient: LinearGradient(colors: [
          c.gold.withValues(alpha: 0.26),
          c.surfaceAlt,
        ]),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.gold.withValues(alpha: 0.18),
              ),
              child: Icon(isHoliday ? AppIcons.mosque : AppIcons.moon,
                  color: c.gold, size: 22),
            ),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(day.name(lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: c.gold, fontWeight: FontWeight.w700)),
                      ),
                      if (day.isMultiDay) ...[
                        const Gap.sm(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: c.gold, borderRadius: AppRadius.rSm),
                          child: Text(
                            'calendar.nthDay'.tr(args: ['${active.index}']),
                            style: const TextStyle(
                                color: Color(0xFF1A1203),
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatGregorian(DateTime.now(), lang)} • ${day.hijri}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary),
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
  final uri =
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
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
    return ref.watch(nearestMosqueProvider).when(
          loading: () => SelayaCard(
            child: Row(
              children: [
                _iconBadge(c),
                const Gap.md(),
                Expanded(
                  child: Text('home.nearestMosqueFinding'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: c.textSecondary)),
                ),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.gold),
                ),
              ],
            ),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (r) {
            // Konum izni yok → spinner yerine net durum (dokun → cami ekranı,
            // izin akışı orada). İzin var ama sonuç yok/zaman aşımı → gizle.
            if (!r.granted) {
              return SelayaCard(
                onTap: () => context.push(Routes.mosques),
                child: Row(
                  children: [
                    _iconBadge(c),
                    const Gap.md(),
                    Expanded(
                      child: Text('home.nearestMosqueNoPermission'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: c.textSecondary)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                  ],
                ),
              );
            }
            final m = r.mosque;
            if (m == null) {
              // Zaman aşımı / sonuç yok: kart KAYBOLMAZ (regresyondu) —
              // "dokun" satırı kalır; provider 1 dk'da bir kendini tazeler.
              return SelayaCard(
                onTap: () => context.push(Routes.mosques),
                child: Row(
                  children: [
                    _iconBadge(c),
                    const Gap.md(),
                    Expanded(
                      child: Text('home.nearestMosqueRetry'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: c.textSecondary)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                  ],
                ),
              );
            }
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
                        Text('home.nearestMosque'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: c.textTertiary)),
                        const SizedBox(height: 1),
                        Text(m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(AppIcons.location, size: 13, color: c.gold),
                            const SizedBox(width: 3),
                            Text(_mosqueDist(m.distanceKm),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: c.gold)),
                            Text('  ·  ${'mosques.directions'.tr()}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: c.textTertiary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.gold.withValues(alpha: 0.12)),
                    child: const Icon(Icons.directions_rounded,
                        color: AppColors.gold, size: 20),
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
            shape: BoxShape.circle, color: c.gold.withValues(alpha: 0.12)),
        child: const Icon(AppIcons.mosque, color: AppColors.gold, size: 20),
      );
}
