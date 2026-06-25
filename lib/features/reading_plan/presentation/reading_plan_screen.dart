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

    final hatimPlans = [
      _HatimPlan(Icons.local_fire_department_rounded, 'xt.rpPlan10Title'.tr(),
          'xt.rpPlan10Desc'.tr(), 60),
      _HatimPlan(Icons.bolt_rounded, 'xt.rpPlan30Title'.tr(),
          'xt.rpPlan30Desc'.tr(), 20),
      _HatimPlan(Icons.calendar_month_rounded, 'xt.rpPlan60Title'.tr(),
          'xt.rpPlan60Desc'.tr(), 10),
      _HatimPlan(Icons.eco_rounded, 'xt.rpPlan90Title'.tr(),
          'xt.rpPlan90Desc'.tr(), 7),
      _HatimPlan(Icons.spa_rounded, 'xt.rpPlan1PageTitle'.tr(),
          'xt.rpPlan1PageDesc'.tr(), 1),
    ];

    final habitPlans = [
      _HabitPlan(Icons.nightlight_round, 'xt.rpHabitMulkTitle'.tr(),
          'xt.rpHabitMulkDesc'.tr(), 67),
      _HabitPlan(Icons.calendar_view_week_rounded, 'xt.rpHabitKahfTitle'.tr(),
          'xt.rpHabitKahfDesc'.tr(), 18),
      _HabitPlan(Icons.wb_twilight_rounded, 'xt.rpHabitYasinTitle'.tr(),
          'xt.rpHabitYasinDesc'.tr(), 36),
      _HabitPlan(Icons.spa_rounded, 'xt.rpHabitRahmanTitle'.tr(),
          'xt.rpHabitRahmanDesc'.tr(), 55),
      _HabitPlan(Icons.volunteer_activism_rounded, 'xt.rpHabitWaqiaTitle'.tr(),
          'xt.rpHabitWaqiaDesc'.tr(), 56),
      _HabitPlan(Icons.bedtime_rounded, 'xt.rpHabitSajdahTitle'.tr(),
          'xt.rpHabitSajdahDesc'.tr(), 32),
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
          _SectionTitle('xt.rpSectionKhatmPlans'.tr()),
          const Gap.sm(),
          for (final p in hatimPlans) ...[
            _PlanCard(
              icon: p.icon,
              title: p.title,
              desc: p.desc,
              action: 'xt.rpActionStart'.tr(),
              meta: 'xt.rpMetaPagesPerDay'.tr(args: [p.dailyPages.toString()]),
              metaIcon: Icons.menu_book_rounded,
              onTap: () => _confirmStart(context, ref, tr,
                  title: p.title, dailyPages: p.dailyPages),
            ),
            const Gap.sm(),
          ],
          // Kendi planını oluştur (kaydırmalı: günde kaç sayfa).
          _PlanCard(
            icon: Icons.tune_rounded,
            title: 'xt.rpCustomPlanTitle'.tr(),
            desc: 'xt.rpCustomPlanDesc'.tr(),
            action: 'xt.rpActionSet'.tr(),
            accent: true,
            onTap: () => _showCustomSheet(context, ref, tr),
          ),
          const Gap.md(),
          _SectionTitle('xt.rpSectionRegularReading'.tr()),
          const Gap.sm(),
          for (final h in habitPlans) ...[
            _PlanCard(
              icon: h.icon,
              title: h.title,
              desc: h.desc,
              action: 'xt.rpActionRead'.tr(),
              meta: 'xt.rpMetaSurah'.tr(args: [h.surah.toString()]),
              metaIcon: Icons.bookmark_rounded,
              onTap: () => context.push('${Routes.quranReader}/${h.surah}'),
            ),
            const Gap.sm(),
          ],
          const Gap.sm(),
          Text(
            'xt.rpFooterNote'.tr(),
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
                  Text('xt.rpCustomSheetTitle'.tr(),
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
                      Text('xt.rpPagesPerDayLabel'.tr(),
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
                    'xt.rpFinishesInDays'.tr(args: [days.toString()]),
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
                            title: 'xt.rpCustomSheetTitle'.tr(),
                            dailyPages: pages);
                      },
                      child: Text('xt.rpStartKhatm'.tr(),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: c.onGold)),
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
              ? 'xt.rpConfirmReplace'.tr(args: [dailyPages.toString()])
              : 'xt.rpConfirmStart'.tr(args: [dailyPages.toString()]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('xt.rpActionStart'.tr()),
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

/// Kısa tarih: "12 Tem" / "12 Jul" (intl + yerel veri gerektirmez).
String _shortDate(DateTime d, bool tr) {
  const trM = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
  ];
  const enM = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${(tr ? trM : enM)[d.month - 1]}';
}

/// Aktif hatim ilerleme kartı: dairesel % halkası + bugün/kalan/tahmini bitiş.
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
    final end = session.estimatedEnd();

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
              // Dairesel ilerleme halkası — % ortada.
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 5,
                        backgroundColor: c.gold.withValues(alpha: 0.16),
                        valueColor: AlwaysStoppedAnimation(c.gold),
                      ),
                    ),
                    Text('%$pctInt',
                        style: TextStyle(
                            color: c.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  ],
                ),
              ),
              const Gap.md(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('xt.rpActiveKhatm'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        if (streak > 0) ...[
                          const Gap.sm(),
                          Icon(Icons.local_fire_department_rounded,
                              size: 15, color: c.gold),
                          Text(' $streak',
                              style: TextStyle(
                                  color: c.gold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ],
                      ],
                    ),
                    const Gap.xxs(),
                    Text(
                        'xt.rpPageProgress'.tr(args: [
                          session.currentPage.toString(),
                          hatimPageTotal.toString()
                        ]),
                        style:
                            TextStyle(color: c.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.gold),
            ],
          ),
          const Gap.md(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat(
                  icon: Icons.today_rounded,
                  text: 'xt.rpStatToday'.tr(
                      args: [today.toString(), target.toString()])),
              _Stat(
                  icon: Icons.flag_rounded,
                  text: 'xt.rpStatLeft'.tr(args: [left.toString()])),
              _Stat(
                  icon: Icons.event_available_rounded,
                  text: 'xt.rpStatFinishBy'.tr(args: [_shortDate(end, tr)])),
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
  final String? meta; // küçük altın rozet (örn. "20 sayfa/gün", "Sûre 67")
  final IconData? metaIcon;
  final VoidCallback onTap;
  const _PlanCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.action,
    required this.onTap,
    this.accent = false,
    this.meta,
    this.metaIcon,
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
                const Gap.xxs(),
                Text(desc,
                    style: TextStyle(
                        color: c.textSecondary, fontSize: 12.5, height: 1.35)),
                if (meta != null) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (metaIcon != null) ...[
                          Icon(metaIcon, size: 12, color: c.gold),
                          const SizedBox(width: 4),
                        ],
                        Text(meta!,
                            style: TextStyle(
                                color: c.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
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
