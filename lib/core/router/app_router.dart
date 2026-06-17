import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/presentation/ai_screen.dart';
import '../../features/akis/presentation/akis_screen.dart';
import '../../features/asma_ul_husna/presentation/asma_screen.dart';
import '../../features/auth/presentation/account_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/daily_tasks/presentation/daily_tasks_screen.dart';
import '../../features/dhikr/presentation/dhikr_screen.dart';
import '../../features/hatim/presentation/hatim_screen.dart';
import '../../features/duas/presentation/duas_screen.dart';
import '../../features/fasting_tracking/presentation/fasting_screen.dart';
import '../../features/inspiration/presentation/inspiration_list_screen.dart';
import '../../features/greetings/presentation/greeting_composer_screen.dart';
import '../../features/guides/domain/guide.dart';
import '../../features/guides/presentation/abdest_rehberi_screen.dart';
import '../../features/guides/presentation/guide_screen.dart';
import '../../features/guides/presentation/namaz_rehberi_screen.dart';
import '../../features/home/presentation/featured_grid_screen.dart';
import '../../features/home/presentation/home_layout_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/ibadah_tracking/presentation/tracking_screen.dart';
import '../../features/kaza_tracking/presentation/kaza_screen.dart';
import '../../features/liked/presentation/liked_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/nearby_mosques/presentation/mosques_screen.dart';
import '../../features/notifications/presentation/adhan_alarm_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';
import '../../features/onboarding/presentation/intro_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../../features/prayer_times/presentation/city_select_screen.dart';
import '../../features/prayer_times/presentation/imsakiye_screen.dart';
import '../../features/prayer_times/presentation/prayer_times_screen.dart';
import '../../features/qibla/presentation/qibla_screen.dart';
import '../../features/quran/presentation/mushaf_screen.dart';
import '../../features/quran/presentation/quran_reader_screen.dart';
import '../../features/quran/presentation/quran_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/social_feed/presentation/feed_screen.dart';
import '../../features/stories/presentation/story_viewer.dart';
import '../../features/tesbihat/presentation/tesbihat_screen.dart';
import '../../features/wallpapers/presentation/wallpapers_screen.dart';
import '../../features/widgets_gallery/presentation/widgets_gallery_screen.dart';
import '../../features/zakat/presentation/zakat_screen.dart';
import '../widgets/mini_player_chrome.dart';
import '../widgets/selaya_bottom_nav.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  GoRoute fs(String path, Widget Function(BuildContext, GoRouterState) builder) =>
      GoRoute(path: path, parentNavigatorKey: rootNavigatorKey, builder: builder);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.intro, builder: (_, _) => const IntroScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.times, builder: (_, _) => const PrayerTimesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.quran, builder: (_, _) => const QuranScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.qibla, builder: (_, _) => const QiblaScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.akis, builder: (_, _) => const AkisScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.more, builder: (_, _) => const MoreScreen()),
          ]),
        ],
      ),

      // Full-screen detail routes (pushed above the shell).
      fs('${Routes.quranReader}/:surah', (_, s) => QuranReaderScreen(
          surahNumber: int.tryParse(s.pathParameters['surah'] ?? '1') ?? 1)),
      // GoRoute (raw push değil) → location '/mushaf' olur; global mini buna
      // bakarak kendini ekranın altına (safe-bottom) konumlar.
      fs(Routes.mushaf, (_, s) =>
          MushafScreen(initialPage: s.extra is int ? s.extra as int : null)),
      fs('${Routes.story}/:index', (_, s) => StoryViewerScreen(
          startIndex: int.tryParse(s.pathParameters['index'] ?? '0') ?? 0)),
      fs(Routes.dhikr, (_, s) => DhikrScreen(
            zikirArabic: s.uri.queryParameters['ar'],
            zikirName: s.uri.queryParameters['name'],
            targetCount: int.tryParse(s.uri.queryParameters['target'] ?? ''),
            taskId: s.uri.queryParameters['task'],
          )),
      fs(Routes.asma, (_, _) => const AsmaScreen()),
      fs(Routes.duas, (_, _) => const DuasScreen()),
      fs(Routes.tesbihat, (_, _) => const TesbihatScreen()),
      fs(Routes.zakat, (_, _) => const ZakatScreen()),
      fs(Routes.verses,
          (_, _) => const InspirationListScreen(
              type: 'verse', titleKey: 'more.verses')),
      fs(Routes.hadiths,
          (_, _) => const InspirationListScreen(
              type: 'hadith', titleKey: 'more.hadiths')),
      fs(Routes.calendar, (_, _) => const CalendarScreen()),
      fs(Routes.tracking, (_, _) => const TrackingScreen()),
      fs(Routes.wallpapers, (_, _) => const WallpapersScreen()),
      fs(Routes.ai, (_, _) => const AiScreen()),
      fs(Routes.mosques, (_, _) => const MosquesScreen()),
      fs(Routes.feed,
          (_, s) => FeedScreen(initialIndex: s.extra is int ? s.extra as int : 0)),
      fs(Routes.settings, (_, _) => const SettingsScreen()),
      fs(Routes.auth, (_, _) => const AuthScreen()),
      fs(Routes.account, (_, _) => const AccountScreen()),
      fs(Routes.liked, (_, _) => const LikedScreen()),
      fs(Routes.premium, (_, _) => const PremiumScreen()),
      fs(Routes.citySelect, (_, _) => const CitySelectScreen()),
      fs(Routes.imsakiye, (_, _) => const ImsakiyeScreen()),
      fs(Routes.notificationSettings,
          (_, _) => const NotificationSettingsScreen()),
      fs(Routes.fasting, (_, _) => const FastingScreen()),
      fs(Routes.greetings, (_, _) => const GreetingComposerScreen()),
      fs(Routes.kaza, (_, _) => const KazaScreen()),
      fs(Routes.tasks, (_, _) => const DailyTasksScreen()),
      fs(Routes.hatim, (_, _) => const HatimScreen()),
      fs(Routes.abdestGuide, (_, _) => const AbdestRehberiScreen()),
      fs(Routes.guideDetail, (_, s) {
        final a = s.extra as ({Guide guide, String collection});
        return GuideScreen(guide: a.guide, collection: a.collection);
      }),
      fs(Routes.namazGuide, (_, _) => const NamazRehberiScreen()),
      fs(Routes.namazHowTo,
          (_, _) =>
              const GuideScreen(guide: namazGuide, collection: 'guide_namaz')),
      fs(Routes.widgetsGallery, (_, _) => const WidgetsGalleryScreen()),
      fs(Routes.homeLayout, (_, _) => const HomeLayoutScreen()),
      fs(Routes.featuredEdit, (_, _) => const FeaturedGridScreen()),
      fs(Routes.yasin, (_, _) => const QuranReaderScreen(surahNumber: 36)),
      fs('${Routes.adhanAlarm}/:slot', (_, s) => AdhanAlarmScreen(
            slotIndex: int.tryParse(s.pathParameters['slot'] ?? '0') ?? 0,
          )),
    ],
  );
});

class _MainShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _MainShell({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Mini çalarlar burada DEĞİL — app.dart'taki GlobalMiniPlayerOverlay tüm
      // rotaların üstünde TEK instance render eder. Navbar'ın yüksekliği,
      // overlay'in "navbar'ın hemen üstü" konumu için ölçülüp paylaşılır.
      body: shell,
      bottomNavigationBar: HeightReporter(
        notifier: navBarHeight,
        child: SelayaBottomNav(
          currentIndex: shell.currentIndex,
          onTap: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      ),
    );
  }
}
