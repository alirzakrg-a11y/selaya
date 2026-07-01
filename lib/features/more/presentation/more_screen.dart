import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/ad_widgets.dart';
import '../../../core/ads/ads_config.dart';
import '../../../core/router/nav.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/review_service.dart';
import '../../auth/data/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
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
      _Entry(Icons.nights_stay_rounded, 'more.specialPrayers',
          Routes.specialPrayers),
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
      _Entry(AppIcons.times, 'nav.times', Routes.times),
      _Entry(Icons.nightlight_round, 'ramadan.title', Routes.ramadan),
      _Entry(Icons.wb_twilight_rounded, 'imsakiye.title', Routes.imsakiye),
      _Entry(AppIcons.calendar, 'calendar.title', Routes.calendar),
      _Entry(AppIcons.mosque, 'mosques.title', Routes.mosques),
    ]),
    _Section('more.secTracking', [
      _Entry(Icons.local_fire_department_rounded, 'streak.title', Routes.streak),
      _Entry(Icons.auto_stories_rounded, 'hatim.title', Routes.hatim),
      _Entry(Icons.groups_rounded, 'communityHatim.title', Routes.communityHatim),
      _Entry(AppIcons.chart, 'tracking.title', Routes.tracking),
      _Entry(AppIcons.fasting, 'fasting.title', Routes.fasting),
      _Entry(AppIcons.kerahat, 'kaza.title', Routes.kaza),
      _Entry(Icons.volunteer_activism_rounded, 'zakat.title', Routes.zakat),
    ]),
    _Section('more.secDiscover', [
      _Entry(Icons.dynamic_feed_rounded, 'nav.akis', Routes.akis),
      _Entry(Icons.quiz_rounded, 'quiz.title', Routes.quiz),
      _Entry(Icons.front_hand_rounded, 'duaWall.title', Routes.duaWall),
      _Entry(Icons.favorite_rounded, 'liked.title', Routes.liked),
      _Entry(AppIcons.headphones, 'audioStories.title', Routes.audioStories),
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
          const Gap.md(),
          const _PremiumCard(),
          const Gap.lg(),
          for (final (i, s) in _sections.indexed) ...[
            _SectionTitle(s.titleKey.tr()),
            const Gap.sm(),
            _Grid(
                entries: s.entries
                    .where((e) =>
                        e.route != Routes.audioStories ||
                        context.locale.languageCode == 'tr')
                    .toList()),
            const Gap.lg(),
            // Özellikler arasına TEK yerel reklam (bezdirmemek için ortalarda).
            if (i == 1) ...[
              const NativeAdCard(),
              const Gap.lg(),
            ],
          ],
          // ⭐ Bizi Değerlendir — uygulama içi yıldız (Play) akışı.
          SelayaCard(
            onTap: () => ReviewService.openReview(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.star_rounded, color: context.colors.gold),
                const Gap.md(),
                Expanded(
                  child: Text(
                    _rateLabel(context.locale.languageCode),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(AppIcons.forward, color: context.colors.gold, size: 18),
              ],
            ),
          ),
          const Gap.lg(),
        ],
      ),
    );
  }
}

/// "Bizi Değerlendir" etiketi (10 dil) — yeni çeviri anahtarı eklememek için.
String _rateLabel(String lang) {
  const m = {
    'tr': 'Bizi Değerlendir ⭐',
    'en': 'Rate us ⭐',
    'ar': 'قيّمنا ⭐',
    'de': 'Bewerte uns ⭐',
    'id': 'Beri nilai ⭐',
    'fr': 'Évaluez-nous ⭐',
    'ur': 'ہمیں ریٹ کریں ⭐',
    'bn': 'আমাদের রেট দিন ⭐',
    'fa': 'به ما امتیاز دهید ⭐',
    'ru': 'Оцените нас ⭐',
  };
  return m[lang] ?? m['en']!;
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
    // 2-sütun ızgara — ikon (sol) + başlık (sağ); ikon & yazı 1 tık BÜYÜK
    // (kullanıcı isteği). Başlık 2 satıra kadar.
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.0,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        return SelayaCard(
          onTap: () => context.openRoute(e.route),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: Row(
            children: [
              FeatureIcon(e.icon, index: i, size: 28),
              const Gap.sm(),
              Expanded(
                child: Text(e.labelKey.tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600, height: 1.1)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// _AiBanner (SELAYA AI Asistanı kartı) KALDIRILDI — AI asistanı komple çıkarıldı.

/// ⭐ SELAYA Plus — göze çarpan altın gradyan tanıtım kartı. Premium ise
/// "aktif üyelik" durumu, değilse "kilidini aç" çağrısı gösterir.
class _PremiumCard extends ConsumerWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    // Altın gradyan — koyu tema üstünde sıcak, "premium" his.
    const gold = Color(0xFFE0B250);
    const goldDeep = Color(0xFFC8912F);
    return GestureDetector(
      onTap: () => context.push(Routes.premium),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          borderRadius: AppRadius.rLg,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gold, goldDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Taç ikonu — koyu daire içinde, kontrast için.
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1206).withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(AppIcons.crown, color: gold, size: 24),
            ),
            const Gap.base(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('SELAYA Plus',
                          style: TextStyle(
                            color: Color(0xFF1A1206),
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 0.2,
                          )),
                      if (isPremium) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded,
                            color: Color(0xFF1A1206), size: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPremium
                        ? _activeLabel(context.locale.languageCode)
                        : 'premium.subtitle'.tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xCC1A1206),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Gap.sm(),
            // "Keşfet/Yönet" hap düğme.
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1206),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isPremium
                    ? _manageLabel(context.locale.languageCode)
                    : _unlockLabel(context.locale.languageCode),
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _activeLabel(String l) {
  const m = {
    'tr': 'Üyeliğin aktif — teşekkürler 🤍',
    'en': 'Your membership is active — thank you 🤍',
    'ar': 'عضويتك فعّالة — شكرًا لك 🤍',
    'de': 'Deine Mitgliedschaft ist aktiv — danke 🤍',
    'id': 'Keanggotaanmu aktif — terima kasih 🤍',
    'fr': 'Votre abonnement est actif — merci 🤍',
    'ur': 'آپ کی رکنیت فعال ہے — شکریہ 🤍',
    'bn': 'আপনার সদস্যপদ সক্রিয় — ধন্যবাদ 🤍',
    'fa': 'عضویت شما فعال است — سپاسگزاریم 🤍',
    'ru': 'Ваша подписка активна — спасибо 🤍',
  };
  return m[l] ?? m['en']!;
}

String _unlockLabel(String l) {
  const m = {
    'tr': 'Keşfet',
    'en': 'Explore',
    'ar': 'اكتشف',
    'de': 'Entdecken',
    'id': 'Jelajahi',
    'fr': 'Découvrir',
    'ur': 'دریافت',
    'bn': 'দেখুন',
    'fa': 'کاوش',
    'ru': 'Открыть',
  };
  return m[l] ?? m['en']!;
}

String _manageLabel(String l) {
  const m = {
    'tr': 'Yönet',
    'en': 'Manage',
    'ar': 'إدارة',
    'de': 'Verwalten',
    'id': 'Kelola',
    'fr': 'Gérer',
    'ur': 'انتظام',
    'bn': 'পরিচালনা',
    'fa': 'مدیریت',
    'ru': 'Управлять',
  };
  return m[l] ?? m['en']!;
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
