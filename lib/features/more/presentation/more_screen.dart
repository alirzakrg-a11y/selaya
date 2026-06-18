import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../auth/data/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_ai_icon.dart';
import '../../../core/widgets/feature_icon.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/selaya_logo.dart';

class _Entry {
  final IconData icon;
  final String labelKey;
  final String route;
  const _Entry(this.icon, this.labelKey, this.route);
}

class _Section {
  final String titleKey;
  final List<_Entry> entries;
  const _Section(this.titleKey, this.entries);
}

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  // Net başlıklı kategoriler (diğer İslami uygulamalardaki gibi düzenli gruplar).
  static const _sections = [
    _Section('more.secQuran', [
      _Entry(AppIcons.quran, 'quran.title', Routes.quran),
      _Entry(Icons.search_rounded, 'quranSearch.title', Routes.quranSearch),
      _Entry(Icons.format_quote_rounded, 'more.verses', Routes.verses),
      _Entry(Icons.history_edu_rounded, 'more.hadiths', Routes.hadiths),
      _Entry(AppIcons.book, 'more.yasin', Routes.yasin),
      _Entry(Icons.event_note_rounded, 'readingPlan.title', Routes.readingPlan),
      _Entry(AppIcons.crown, 'asma.title', Routes.asma),
    ]),
    _Section('more.secWorship', [
      _Entry(Icons.self_improvement_rounded, 'more.namazGuide',
          Routes.namazGuide),
      _Entry(Icons.water_drop_rounded, 'more.abdestGuide', Routes.abdestGuide),
      _Entry(Icons.travel_explore_rounded, 'hajj.title', Routes.hajj),
      _Entry(Icons.flight_rounded, 'travel.title', Routes.travel),
      _Entry(Icons.menu_book_rounded, 'ilmihal.title', Routes.ilmihal),
      _Entry(AppIcons.tasbih, 'dhikr.title', Routes.dhikr),
      _Entry(Icons.repeat_rounded, 'tesbihat.title', Routes.tesbihat),
      _Entry(AppIcons.dua, 'duas.title', Routes.duas),
      _Entry(AppIcons.qibla, 'qibla.title', Routes.qibla),
    ]),
    _Section('more.secTimes', [
      _Entry(Icons.wb_twilight_rounded, 'imsakiye.title', Routes.imsakiye),
      _Entry(AppIcons.calendar, 'calendar.title', Routes.calendar),
      _Entry(AppIcons.mosque, 'mosques.title', Routes.mosques),
    ]),
    _Section('more.secTracking', [
      _Entry(Icons.local_fire_department_rounded, 'streak.title', Routes.streak),
      _Entry(Icons.auto_stories_rounded, 'hatim.title', Routes.hatim),
      _Entry(AppIcons.chart, 'tracking.title', Routes.tracking),
      _Entry(AppIcons.fasting, 'fasting.title', Routes.fasting),
      _Entry(AppIcons.kerahat, 'kaza.title', Routes.kaza),
      _Entry(Icons.savings_rounded, 'zakat.title', Routes.zakat),
    ]),
    _Section('more.secDiscover', [
      _Entry(Icons.favorite_rounded, 'liked.title', Routes.liked),
      _Entry(Icons.child_friendly_rounded, 'babyNames.title', Routes.babyNames),
      _Entry(AppIcons.play, 'akis.reels', Routes.feed),
      _Entry(AppIcons.card, 'greetings.title', Routes.greetings),
    ]),
    _Section('more.secCustomize', [
      _Entry(AppIcons.wallpaper, 'wallpapers.title', Routes.wallpapers),
      _Entry(AppIcons.tune, 'widgetsGallery.title', Routes.widgetsGallery),
      _Entry(Icons.dashboard_customize_rounded, 'homeLayout.title',
          Routes.homeLayout),
    ]),
    _Section('more.secApp', [
      _Entry(Icons.alarm_rounded, 'reminders.title', Routes.reminders),
      _Entry(AppIcons.settings, 'settings.title', Routes.settings),
      _Entry(AppIcons.info, 'intro.welcome', Routes.intro),
    ]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SelayaScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.lg, AppSpacing.base, AppSpacing.xxxl),
        children: [
          Row(
            children: [
              const SelayaLogo(size: 40, showWordmark: false),
              const Gap.md(),
              Text('common.more'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const Gap.lg(),
          const _AccountCard(),
          const Gap.sm(),
          const _AiBanner(),
          const Gap.lg(),
          for (final s in _sections) ...[
            _SectionTitle(s.titleKey.tr()),
            const Gap.sm(),
            _Grid(entries: s.entries),
            const Gap.lg(),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
            text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.colors.gold,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700)),
      );
}

class _Grid extends StatelessWidget {
  final List<_Entry> entries;
  const _Grid({required this.entries});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Alt alta liste — her araç bir satır (ikon + başlık + ok).
    return Column(
      children: [
        for (final (i, e) in entries.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SelayaCard(
              onTap: () => context.push(e.route),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  FeatureIcon(e.icon, index: i),
                  const Gap.md(),
                  Expanded(
                    child: Text(e.labelKey.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Icon(AppIcons.forward, color: c.textTertiary, size: 20),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AiBanner extends StatelessWidget {
  const _AiBanner();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Küçük + temaya uyumlu (eskiden büyük sabit-renk banner'dı).
    return SelayaCard(
      onTap: () => context.push(Routes.ai),
      borderRadius: AppRadius.rLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [c.gold, c.goldBright]),
            ),
            child: AnimatedAiIcon(color: c.bg, size: 20),
          ),
          const Gap.base(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ai.title'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('home.askSelayaDesc'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Icon(AppIcons.forward, color: c.gold),
        ],
      ),
    );
  }
}

/// Üyelik kartı — giriş yapılmışsa "Hesabım" (ad+e-posta), değilse "Giriş/Üye ol".
class _AccountCard extends ConsumerWidget {
  const _AccountCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(authControllerProvider).user;
    final loggedIn = user != null;
    return SelayaCard(
      onTap: () => context.push(loggedIn ? Routes.account : Routes.auth),
      borderRadius: AppRadius.rLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: c.gold.withValues(alpha: 0.18),
            child: loggedIn
                ? Text(user.initials,
                    style:
                        TextStyle(color: c.gold, fontWeight: FontWeight.w800))
                : Icon(Icons.person_outline_rounded, color: c.gold),
          ),
          const Gap.base(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loggedIn ? user.fullName : 'auth.guestTitle'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(loggedIn ? user.email : 'auth.guestDesc'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Icon(AppIcons.forward, color: c.gold),
        ],
      ),
    );
  }
}
