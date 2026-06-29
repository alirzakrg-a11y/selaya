import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confetti_overlay.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/router/routes.dart';
import '../../hatim/data/hatim_controller.dart';
import '../../hatim/domain/hatim_session.dart';
import '../data/daily_tasks_controller.dart';
import '../domain/daily_task.dart';

/// "Günlük Görevler" (#18): 5 rotating tasks a day, completion that persists,
/// a weekly bar chart and earnable badges. Senior-friendly — large text, big
/// tap targets, clear progress.
class DailyTasksScreen extends ConsumerWidget {
  const DailyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lang = context.langCode;
    final tasks = dailyTasksFor(DateTime.now());
    // Watch the log STATE (not the notifier) so the UI rebuilds on every toggle.
    final log = ref.watch(dailyTasksProvider);
    final done = log[DailyTasksController.dateKey(DateTime.now())] ?? const <String>[];
    final stats = ref.watch(taskStatsProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text('tasks.title'.tr()),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xxxl),
        children: [
          _ProgressHero(done: stats.todayDone, total: dailyTaskCount, streak: stats.streak),
          const Gap.lg(),
          Text('tasks.today'.tr(),
              style: Theme.of(context).textTheme.titleMedium),
          const Gap.sm(),
          // Aktif hatim varsa dinamik görev (kütüphane dışı): bugünkü sayfa hedefi.
          if (ref.watch(hatimControllerProvider).active
                  case final h?
              when h.status == HatimStatus.active) ...[
            _HatimTaskRow(session: h),
            const Gap.sm(),
          ],
          for (final t in tasks) ...[
            _TaskRow(
              task: t,
              done: done.contains(t.id),
              onToggle: () => _toggle(context, ref, t.id),
            ),
            const Gap.sm(),
          ],
          const Gap.md(),
          Text('tasks.weekly'.tr(),
              style: Theme.of(context).textTheme.titleMedium),
          const Gap.sm(),
          _WeeklyChart(last7: stats.last7, target: dailyTaskCount),
          const Gap.lg(),
          Text('tasks.badges'.tr(),
              style: Theme.of(context).textTheme.titleMedium),
          const Gap.sm(),
          _BadgeWrap(stats: stats, lang: lang),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, String id) async {
    final ctrl = ref.read(dailyTasksProvider.notifier);
    final wasDone = ctrl.isDoneToday(id);
    await ctrl.toggleToday(id);
    // Celebrate the moment the day is fully completed.
    if (!wasDone &&
        ctrl.doneOn(DateTime.now()).length >= dailyTaskCount &&
        context.mounted) {
      celebrate(context); // 🎆 havai fişek
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('tasks.allDone'.tr())));
    }
  }
}

/// Top hero: a ring with "done/total" + a streak chip.
class _ProgressHero extends StatelessWidget {
  final int done;
  final int total;
  final int streak;
  const _ProgressHero(
      {required this.done, required this.total, required this.streak});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ratio = total == 0 ? 0.0 : done / total;
    return SelayaCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 7,
                    backgroundColor: c.border,
                    valueColor: AlwaysStoppedAnimation(c.gold),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text('$done/$total',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Gap.base(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    done >= total
                        ? 'tasks.heroDone'.tr()
                        : 'tasks.heroProgress'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        size: 18,
                        color: streak > 0 ? c.gold : c.textTertiary),
                    const SizedBox(width: 4),
                    Text('tasks.streak'.tr(args: ['$streak']),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: c.textSecondary)),
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

/// One task row — big tap target. Tap toggles completion; the "Aç" link (when
/// the task has a destination) jumps to that feature.
class _TaskRow extends StatelessWidget {
  final DailyTaskDef task;
  final bool done;
  final VoidCallback onToggle;
  const _TaskRow(
      {required this.task, required this.done, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.langCode;
    return SelayaCard(
      onTap: onToggle,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (done ? c.success : c.gold).withValues(alpha: 0.14),
            ),
            child: Icon(task.icon,
                color: done ? c.success : c.gold, size: 24),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title(lang),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: done ? c.textTertiary : c.textPrimary,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: c.textTertiary,
                        )),
                if (task.navRoute != null)
                  GestureDetector(
                    onTap: () => context.push(task.navRoute!),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      margin: const EdgeInsets.only(top: 7),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: c.gold.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('tasks.open'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: c.gold,
                                      fontWeight: FontWeight.w800)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              size: 16, color: c.gold),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Gap.sm(),
          // Big completion toggle.
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? c.success : Colors.transparent,
              border: Border.all(
                  color: done ? c.success : c.border, width: 2),
            ),
            child: Icon(Icons.check_rounded,
                size: 20, color: done ? Colors.white : Colors.transparent),
          ),
        ],
      ),
    );
  }
}

/// 7-day mini bar chart (oldest → newest, today last).
class _WeeklyChart extends StatelessWidget {
  final List<int> last7;
  final int target;
  const _WeeklyChart({required this.last7, required this.target});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    return SelayaCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.sm),
      child: SizedBox(
        height: 116,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < last7.length; i++)
              Expanded(
                child: _Bar(
                  ratio: target == 0 ? 0 : last7[i] / target,
                  count: last7[i],
                  label: DateFormat('E', context.langCode)
                      .format(now.subtract(Duration(days: 6 - i))),
                  isToday: i == last7.length - 1,
                  color: c.gold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double ratio;
  final int count;
  final String label;
  final bool isToday;
  final Color color;
  const _Bar(
      {required this.ratio,
      required this.count,
      required this.label,
      required this.isToday,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$count',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: c.textTertiary)),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 14,
                height: (box.maxHeight * ratio).clamp(4.0, box.maxHeight),
                decoration: BoxDecoration(
                  color: ratio >= 1
                      ? color
                      : color.withValues(alpha: ratio == 0 ? 0.15 : 0.55),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isToday ? c.gold : c.textTertiary,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }
}

/// Earnable badges — earned ones in gold, locked ones greyed.
class _BadgeWrap extends StatelessWidget {
  final TaskStats stats;
  final String lang;
  const _BadgeWrap({required this.stats, required this.lang});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final b in taskBadges)
          () {
            final earned = b.earned(stats);
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: earned
                    ? c.gold.withValues(alpha: 0.14)
                    : c.surfaceAlt,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                    color: earned ? c.gold : c.border,
                    width: earned ? 1.4 : 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(b.icon,
                      size: 18,
                      color: earned ? c.gold : c.textTertiary),
                  const SizedBox(width: 6),
                  Text(b.title(lang),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: earned ? c.textPrimary : c.textTertiary,
                            fontWeight:
                                earned ? FontWeight.w700 : FontWeight.w500,
                          )),
                ],
              ),
            );
          }(),
      ],
    );
  }
}

/// Aktif hatim varsa günlük görevlere eklenen dinamik satır: bugünkü sayfa
/// hedefi (kütüphane görevi DEĞİL — hatim durumundan türetilir).
class _HatimTaskRow extends StatelessWidget {
  final HatimSession session;
  const _HatimTaskRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final read = session.readToday();
    final target = session.dailyTarget;
    final done = read >= target;
    return SelayaCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (done ? c.success : c.gold).withValues(alpha: 0.14),
            ),
            child: Icon(Icons.auto_stories_rounded,
                color: done ? c.success : c.gold, size: 24),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('hatim.taskTitle'.tr(args: ['$target']),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: done ? c.textTertiary : c.textPrimary,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: c.textTertiary,
                        )),
                GestureDetector(
                  onTap: () => context.push(Routes.hatim),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.only(top: 7),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: c.gold.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$read/$target',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: c.gold)),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded,
                            size: 16, color: c.gold),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (done) Icon(Icons.check_circle_rounded, color: c.success, size: 26),
        ],
      ),
    );
  }
}
