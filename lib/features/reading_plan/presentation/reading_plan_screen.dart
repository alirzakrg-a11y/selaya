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

/// 📅 KUR'AN OKUMA PLANI — hazır plan şablonları. Hatim planları mevcut Hatim
/// Takibi motorunu (günlük hedef) kullanır; düzenli okuma kartları ilgili sûreyi
/// açar. Yeni bir takip sistemi DEĞİL; var olanın üstüne rehberlik katmanı.
class ReadingPlanScreen extends ConsumerWidget {
  const ReadingPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = context.langCode == 'tr';
    final c = context.colors;

    final hatimPlans = tr
        ? const [
            _HatimPlan(Icons.bolt_rounded, '30 Günde Hatim',
                'Günde 1 cüz (yaklaşık 20 sayfa). Ramazan için ideal.', 20),
            _HatimPlan(Icons.calendar_month_rounded, '60 Günde Hatim',
                'Günde yaklaşık 10 sayfa. Dengeli bir tempo.', 10),
            _HatimPlan(Icons.spa_rounded, 'Günde 1 Sayfa',
                'Acele etmeden, her gün tek sayfa ile kalıcı alışkanlık.', 1),
          ]
        : const [
            _HatimPlan(Icons.bolt_rounded, 'Khatm in 30 days',
                '1 juz (~20 pages) a day. Ideal for Ramadan.', 20),
            _HatimPlan(Icons.calendar_month_rounded, 'Khatm in 60 days',
                'About 10 pages a day. A balanced pace.', 10),
            _HatimPlan(Icons.spa_rounded, '1 page a day',
                'No rush — one page daily for a lasting habit.', 1),
          ];

    final habitPlans = tr
        ? const [
            _HabitPlan(Icons.nightlight_round, 'Her Gece: Mülk Sûresi',
                'Kabir azabından koruyan sûre (Tebâreke).', 67),
            _HabitPlan(Icons.calendar_view_week_rounded, 'Her Cuma: Kehf Sûresi',
                'İki Cuma arası nurlanma müjdesi.', 18),
            _HabitPlan(Icons.favorite_rounded, 'Her Sabah: Yâsîn',
                'Kur\'an\'ın kalbi; güne Yâsîn ile başlayın.', 36),
            _HabitPlan(Icons.water_drop_rounded, 'Rahmân Sûresi',
                'Kur\'an\'ın gelini; nimetleri ananan sûre.', 55),
          ]
        : const [
            _HabitPlan(Icons.nightlight_round, 'Every night: Al-Mulk',
                'The surah that protects from the grave.', 67),
            _HabitPlan(Icons.calendar_view_week_rounded, 'Every Friday: Al-Kahf',
                'Light between the two Fridays.', 18),
            _HabitPlan(Icons.favorite_rounded, 'Every morning: Ya-Sin',
                'The heart of the Quran; start your day with it.', 36),
            _HabitPlan(Icons.water_drop_rounded, 'Ar-Rahman',
                'The bride of the Quran; recounting His blessings.', 55),
          ];

    return SelayaScaffold(
      title: 'readingPlan.title'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          _SectionTitle(tr ? 'HATİM PLANLARI' : 'KHATM PLANS'),
          const Gap.sm(),
          for (final p in hatimPlans) ...[
            _PlanCard(
              icon: p.icon,
              title: p.title,
              desc: p.desc,
              action: tr ? 'Başlat' : 'Start',
              onTap: () => _startHatim(context, ref, tr, p),
            ),
            const Gap.sm(),
          ],
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

  Future<void> _startHatim(
      BuildContext context, WidgetRef ref, bool tr, _HatimPlan plan) async {
    final c = context.colors;
    final hasActive = ref.read(hatimControllerProvider).active != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plan.title),
        content: Text(
          hasActive
              ? (tr
                  ? 'Bu planla yeni bir hatim başlatılsın mı? Aktif hatminiz '
                      'geçmişe taşınacak.'
                  : 'Start a new khatm with this plan? Your active khatm will '
                      'move to history.')
              : (tr
                  ? 'Bu planla hatim başlatılsın mı? (Günde ${plan.dailyPages} sayfa)'
                  : 'Start a khatm with this plan? (${plan.dailyPages} pages/day)'),
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
        .start(startPage: 1, dailyTarget: plan.dailyPages);
    if (context.mounted) context.push(Routes.hatim);
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
  final VoidCallback onTap;
  const _PlanCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.gold.withValues(alpha: 0.14),
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
