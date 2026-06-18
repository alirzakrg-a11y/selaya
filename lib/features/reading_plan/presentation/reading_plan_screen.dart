import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../hatim/data/hatim_controller.dart';
import '../../hatim/domain/hatim_session.dart';

/// Bir hatim planı şablonu (günlük sayfa hedefi → Hatim Takibi'ni başlatır).
class _HatimPlan {
  final IconData icon;
  final String title;
  final String desc;
  final int dailyPages;
  const _HatimPlan(this.icon, this.title, this.desc, this.dailyPages);
}

/// Düzenli okuma alışkanlığı (belirli bir sûreyi açar).
class _HabitPlan {
  final IconData icon;
  final String title;
  final String desc;
  final int surah;
  const _HabitPlan(this.icon, this.title, this.desc, this.surah);
}

/// 📅 KUR'AN OKUMA PLANI — aktif hatim ilerlemesi + hazır plan şablonları +
/// kendi planını oluştur. Hatim planları mevcut Hatim Takibi motorunu (günlük
/// hedef) kullanır; düzenli okuma kartları ilgili sûreyi açar. Yeni bir takip
/// sistemi DEĞİL; var olanın üstüne rehberlik katmanı.
class ReadingPlanScreen extends ConsumerWidget {
  const ReadingPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = context.langCode == 'tr';
    final c = context.colors;
    final active = ref.watch(hatimControllerProvider).active;

    final hatimPlans = tr
        ? const [
            _HatimPlan(Icons.local_fire_department_rounded, '10 Günde Hatim',
                'Günde ~60 sayfa (3 cüz). Ramazan’ın son 10 gecesi için.', 60),
            _HatimPlan(Icons.bolt_rounded, '30 Günde Hatim',
                'Günde 1 cüz (~20 sayfa). Ramazan için ideal.', 20),
            _HatimPlan(Icons.calendar_month_rounded, '60 Günde Hatim',
                'Günde ~10 sayfa. Dengeli bir tempo.', 10),
            _HatimPlan(Icons.eco_rounded, '90 Günde Hatim',
                'Günde ~7 sayfa. Sakin ve sürdürülebilir.', 7),
            _HatimPlan(Icons.spa_rounded, 'Günde 1 Sayfa',
                'Acele etmeden, her gün tek sayfa ile kalıcı alışkanlık.', 1),
          ]
        : const [
            _HatimPlan(Icons.local_fire_department_rounded, 'Khatm in 10 days',
                '~60 pages (3 juz) a day. For the last 10 nights of Ramadan.', 60),
            _HatimPlan(Icons.bolt_rounded, 'Khatm in 30 days',
                '1 juz (~20 pages) a day. Ideal for Ramadan.', 20),
            _HatimPlan(Icons.calendar_month_rounded, 'Khatm in 60 days',
                'About 10 pages a day. A balanced pace.', 10),
            _HatimPlan(Icons.eco_rounded, 'Khatm in 90 days',
                'About 7 pages a day. Calm and sustainable.', 7),
            _HatimPlan(Icons.spa_rounded, '1 page a day',
                'No rush — one page daily for a lasting habit.', 1),
          ];

    final habitPlans = tr
        ? const [
            _HabitPlan(Icons.nightlight_round, 'Her Gece: Mülk Sûresi',
                'Kabir azabından koruyan sûre (Tebâreke).', 67),
            _HabitPlan(Icons.calendar_view_week_rounded, 'Her Cuma: Kehf Sûresi',
                'İki Cuma arası nurlanma müjdesi.', 18),
            _HabitPlan(Icons.wb_twilight_rounded, 'Her Sabah: Yâsîn',
                'Kur\'an\'ın kalbi; güne Yâsîn ile başlayın.', 36),
            _HabitPlan(Icons.spa_rounded, 'Rahmân Sûresi',
                'Kur\'an\'ın gelini; nimetleri anan sûre.', 55),
            _HabitPlan(Icons.volunteer_activism_rounded, 'Her Gece: Vâkıa',
                'Bereket ve rızık niyetiyle okunagelen sûre.', 56),
            _HabitPlan(Icons.bedtime_rounded, 'Cuma Gecesi: Secde',
                'Cuma gecesi okunması güzel görülen sûre.', 32),
          ]
        : const [
            _HabitPlan(Icons.nightlight_round, 'Every night: Al-Mulk',
                'The surah that protects from the grave.', 67),
            _HabitPlan(Icons.calendar_view_week_rounded, 'Every Friday: Al-Kahf',
                'Light between the two Fridays.', 18),
            _HabitPlan(Icons.wb_twilight_rounded, 'Every morning: Ya-Sin',
                'The heart of the Quran; start your day with it.', 36),
            _HabitPlan(Icons.spa_rounded, 'Ar-Rahman',
                'The bride of the Quran; recounting His blessings.', 55),
            _HabitPlan(Icons.volunteer_activism_rounded, 'Every night: Al-Waqi\'ah',
                'Recited seeking blessing and provision.', 56),
            _HabitPlan(Icons.bedtime_rounded, 'Friday night: As-Sajdah',
                'Recommended to recite on Friday night.', 32),
          ];

    return SelayaScaffold(
      title: 'readingPlan.title'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          // Aktif hatim varsa: ilerleme kartı (devam etmek için tek dokunuş).
          if (active != null && active.status == HatimStatus.active) ...[
            _ActiveHatimHero(
                session: active,
                tr: tr,
                onTap: () => context.push(Routes.hatim)),
            const Gap.md(),
          ],
          _SectionTitle(tr ? 'HATİM PLANLARI' : 'KHATM PLANS'),
          const Gap.sm(),
          for (final p in hatimPlans) ...[
            _PlanCard(
              icon: p.icon,
              title: p.title,
              desc: p.desc,
              action: tr ? 'Başlat' : 'Start',
              onTap: () => _confirmStart(context, ref, tr,
                  title: p.title, dailyPages: p.dailyPages),
            ),
            const Gap.sm(),
          ],
          // Kendi planını oluştur (kaydırmalı: günde kaç sayfa).
          _PlanCard(
            icon: Icons.tune_rounded,
            title: tr ? 'Kendi Planını Oluştur' : 'Create Your Own Plan',
            desc: tr
                ? 'Günde kaç sayfa okumak istediğini sen seç.'
                : 'Choose how many pages you read per day.',
            action: tr ? 'Ayarla' : 'Set',
            accent: true,
            onTap: () => _showCustomSheet(context, ref, tr),
          ),
          const Gap.md(),
          _SectionTitle(tr ? 'DÜZENLİ OKUMA' : 'REGULAR READING'),
          const Gap.sm(),
          for (final h in habitPlans) ...[
            _PlanCard(
              icon: h.icon,
              title: h.title,
              desc: h.desc,
              action: tr ? 'Oku' : 'Read',
              onTap: () => context.push('${Routes.quranReader}/${h.surah}'),
            ),
            const Gap.sm(),
          ],
          const Gap.sm(),
          Text(
            tr
                ? 'Hatim planları, ilerlemenizi takip eden Hatim Takibi ekranını '
                    'kullanır. Düzenli okuma kartları ilgili sûreyi açar.'
                : 'Khatm plans use the Hatim tracker that follows your progress. '
                    'Regular-reading cards open the relevant surah.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textTertiary, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  // Günde kaç sayfa? — kaydırmalı özel plan.
  void _showCustomSheet(BuildContext context, WidgetRef ref, bool tr) {
    var pages = 10;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        final c = sheetCtx.colors;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final days = (hatimPageTotal / pages).ceil();
            return Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                  AppSpacing.lg, AppSpacing.lg + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr ? 'Kendi Planın' : 'Custom Plan',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Gap.md(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$pages',
                          style: TextStyle(
                              color: c.gold,
                              fontSize: 34,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 6),
                      Text(tr ? 'sayfa / gün' : 'pages / day',
                          style: TextStyle(color: c.textSecondary)),
                    ],
                  ),
                  Slider(
                    value: pages.toDouble(),
                    min: 1,
                    max: 40,
                    divisions: 39,
                    activeColor: c.gold,
                    label: '$pages',
                    onChanged: (v) => setSheet(() => pages = v.round()),
                  ),
                  Text(
                    tr ? '≈ $days günde hatim tamamlanır' : '≈ finishes in $days days',
                    style: TextStyle(color: c.gold, fontWeight: FontWeight.w700),
                  ),
                  const Gap.lg(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: c.gold,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmStart(context, ref, tr,
                            title: tr ? 'Kendi Planın' : 'Custom Plan',
                            dailyPages: pages);
                      },
                      child: Text(tr ? 'Hatmi Başlat' : 'Start Khatm',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1203))),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmStart(
    BuildContext context,
    WidgetRef ref,
    bool tr, {
    required String title,
    required int dailyPages,
  }) async {
    final c = context.colors;
    final hasActive = ref.read(hatimControllerProvider).active != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          hasActive
              ? (tr
                  ? 'Bu planla yeni bir hatim başlatılsın mı? Aktif hatminiz '
                      'geçmişe taşınacak. (Günde $dailyPages sayfa)'
                  : 'Start a new khatm with this plan? Your active khatm will '
                      'move to history. ($dailyPages pages/day)')
              : (tr
                  ? 'Bu planla hatim başlatılsın mı? (Günde $dailyPages sayfa)'
                  : 'Start a khatm with this plan? ($dailyPages pages/day)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr ? 'Başlat' : 'Start'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(hatimControllerProvider.notifier)
        .start(startPage: 1, dailyTarget: dailyPages);
    if (context.mounted) context.push(Routes.hatim);
  }
}

/// Aktif hatim ilerleme kartı: yüzde + ilerleme çubuğu + bugün/kalan/seri.
class _ActiveHatimHero extends StatelessWidget {
  final HatimSession session;
  final bool tr;
  final VoidCallback onTap;
  const _ActiveHatimHero(
      {required this.session, required this.tr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = session.percent;
    final pctInt = (pct * 100).round();
    final today = session.readToday();
    final target = session.dailyTarget;
    final left = session.pagesLeft;
    final streak = session.streak();

    return SelayaCard(
      onTap: onTap,
      gradient: LinearGradient(
        colors: [c.gold.withValues(alpha: 0.22), c.surfaceAlt],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories_rounded, color: c.gold, size: 20),
              const Gap.sm(),
              Text(tr ? 'Aktif Hatim' : 'Active Khatm',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(tr ? 'Devam Et' : 'Continue',
                  style: TextStyle(
                      color: c.gold, fontWeight: FontWeight.w700, fontSize: 13)),
              Icon(Icons.chevron_right_rounded, color: c.gold, size: 18),
            ],
          ),
          const Gap.md(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('%$pctInt',
                  style: TextStyle(
                      color: c.gold,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1)),
              const Spacer(),
              Text(
                  tr
                      ? 'Sayfa ${session.currentPage} / $hatimPageTotal'
                      : 'Page ${session.currentPage} / $hatimPageTotal',
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            ],
          ),
          const Gap.sm(),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: c.gold.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation(c.gold),
            ),
          ),
          const Gap.md(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat(
                  icon: Icons.today_rounded,
                  text: tr
                      ? 'Bugün $today/$target sayfa'
                      : 'Today $today/$target'),
              _Stat(
                  icon: Icons.flag_rounded,
                  text: tr ? 'Kalan $left sayfa' : '$left pages left'),
              if (streak > 0)
                _Stat(
                    icon: Icons.local_fire_department_rounded,
                    text: tr ? '$streak gün seri' : '$streak-day streak'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Stat({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c.gold),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
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
        child: Text(text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.colors.gold,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700)),
      );
}

class _PlanCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final String action;
  final bool accent;
  final VoidCallback onTap;
  const _PlanCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.action,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      gradient: accent
          ? LinearGradient(
              colors: [c.gold.withValues(alpha: 0.16), c.surfaceAlt],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.gold.withValues(alpha: accent ? 0.22 : 0.14),
            ),
            child: Icon(icon, color: c.gold, size: 22),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(
                        color: c.textSecondary, fontSize: 12.5, height: 1.35)),
              ],
            ),
          ),
          const Gap.sm(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action,
                  style: TextStyle(
                      color: c.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              Icon(Icons.chevron_right_rounded, color: c.gold, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}
