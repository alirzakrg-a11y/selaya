import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../data/hatim_controller.dart';
import '../domain/hatim_session.dart';
import 'hatim_complete_view.dart';

/// 📖 HATİM TAKİBİ — Kur'an'ı baştan sona okuma sürecini takip eder.
/// Boş durum → başlatma → ilerleme; tamamlanınca kutlama. Tamamen offline.
class HatimScreen extends ConsumerWidget {
  const HatimScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(hatimControllerProvider);
    final active = data.active;
    return SelayaScaffold(
      title: 'hatim.title'.tr(),
      showBack: true,
      body: active == null
          ? _Empty(history: data.history)
          : active.status == HatimStatus.completed
              ? HatimCompleteView(session: active)
              : _Progress(session: active, history: data.history),
    );
  }
}

void openMushafAt(BuildContext context, int page) {
  // go: Mushaf kabuk-altı rota — Kur'an sekmesine geçirir, alt menü görünür.
  context.go(Routes.mushaf, extra: page.clamp(1, hatimPageTotal));
}

// ─────────────────────────── BOŞ DURUM ───────────────────────────
class _Empty extends ConsumerWidget {
  final List<HatimSession> history;
  const _Empty({required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.lg, AppSpacing.base, AppSpacing.xxxl),
      children: [
        const Gap.xl(),
        Icon(Icons.auto_stories_rounded, size: 72, color: c.gold),
        const Gap.lg(),
        Text('hatim.emptyTitle'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const Gap.sm(),
        Text('hatim.emptyDesc'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: c.textSecondary)),
        const Gap.xl(),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: c.gold,
              foregroundColor: c.bg,
              padding: const EdgeInsets.symmetric(vertical: 16)),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('hatim.start'.tr()),
          onPressed: () => showHatimStartSheet(context, ref),
        ),
        if (history.isNotEmpty) ...[
          const Gap.xl(),
          _HistoryList(history: history),
        ],
      ],
    );
  }
}

// ─────────────────────────── İLERLEME ───────────────────────────
class _Progress extends ConsumerWidget {
  final HatimSession session;
  final List<HatimSession> history;
  const _Progress({required this.session, required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lang = context.langCode;
    final s = session;
    final readToday = s.readToday();
    final pct = (s.percent * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xxxl),
      children: [
        // Büyük dairesel ilerleme
        SelayaCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              SizedBox(
                width: 168,
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 168,
                      height: 168,
                      child: CircularProgressIndicator(
                        value: s.percent,
                        strokeWidth: 12,
                        backgroundColor: c.border,
                        valueColor: AlwaysStoppedAnimation(c.gold),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('%$pct',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    color: c.gold,
                                    fontWeight: FontWeight.w800)),
                        Text(
                            'hatim.pageOf'.tr(args: [
                              '${s.currentPage}',
                              '$hatimPageTotal'
                            ]),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap.md(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat(
                      icon: Icons.local_fire_department_rounded,
                      value: '${s.streak()}',
                      label: 'hatim.streak'.tr()),
                  _Stat(
                      icon: Icons.event_rounded,
                      value: formatGregorian(s.estimatedEnd(), lang),
                      label: 'hatim.estEnd'.tr()),
                  _Stat(
                      icon: Icons.menu_book_rounded,
                      value: '${s.pagesLeft}',
                      label: 'hatim.pagesLeft'.tr()),
                ],
              ),
            ],
          ),
        ),
        const Gap.md(),
        // Bugünkü hedef kartı
        SelayaCard(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('hatim.todayTitle'.tr(),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Text('$readToday/${s.dailyTarget}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: readToday >= s.dailyTarget
                              ? c.success
                              : c.gold,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const Gap.sm(),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: s.dailyTarget == 0
                      ? 0
                      : (readToday / s.dailyTarget).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: c.border,
                  valueColor: AlwaysStoppedAnimation(
                      readToday >= s.dailyTarget ? c.success : c.gold),
                ),
              ),
              const Gap.xs(),
              Text(
                  readToday >= s.dailyTarget
                      ? 'hatim.todayDone'.tr()
                      : 'hatim.todayLeft'
                          .tr(args: ['${s.dailyTarget - readToday}']),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
        const Gap.md(),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: c.gold,
              foregroundColor: c.bg,
              padding: const EdgeInsets.symmetric(vertical: 15)),
          icon: const Icon(Icons.auto_stories_rounded),
          label: Text('hatim.continue'.tr()),
          onPressed: () => openMushafAt(context, s.currentPage + 1),
        ),
        const Gap.sm(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('hatim.addPages'.tr()),
                onPressed: () => _addPagesDialog(context, ref),
              ),
            ),
            const Gap.sm(),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: c.danger),
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: Text('hatim.abandon'.tr()),
                onPressed: () => _abandonDialog(context, ref),
              ),
            ),
          ],
        ),
        if (history.isNotEmpty) ...[
          const Gap.xl(),
          _HistoryList(history: history),
        ],
      ],
    );
  }

  Future<void> _addPagesDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: '1');
    final c = context.colors;
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('hatim.addPages'.tr()),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: 'hatim.addPagesHint'.tr()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.gold),
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text.trim()) ?? 0),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    if (n != null && n > 0) {
      await ref.read(hatimControllerProvider.notifier).addPagesManual(n);
    }
  }

  Future<void> _abandonDialog(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('hatim.abandonTitle'.tr()),
        content: Text('hatim.abandonBody'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: context.colors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('hatim.abandon'.tr()),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(hatimControllerProvider.notifier).abandon();
    }
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Icon(icon, color: c.gold, size: 20),
        const Gap.xs(),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: c.textTertiary)),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<HatimSession> history;
  const _HistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.langCode;
    final done = history.where((h) => h.status == HatimStatus.completed).toList();
    if (done.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('hatim.history'.tr(),
            style: Theme.of(context).textTheme.titleMedium),
        const Gap.sm(),
        for (final h in done)
          SelayaCard(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, color: c.success, size: 24),
                const Gap.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${formatGregorian(h.startDate, lang)} – ${formatGregorian(h.completedDate ?? h.startDate, lang)}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      Text('hatim.daysCount'.tr(args: ['${h.dayCount}']),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: c.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────── BAŞLATMA SHEET ───────────────────────────
void showHatimStartSheet(BuildContext context, WidgetRef ref) {
  final c = context.colors;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _StartSheet(parentRef: ref),
  );
}

class _StartSheet extends ConsumerStatefulWidget {
  final WidgetRef parentRef;
  const _StartSheet({required this.parentRef});
  @override
  ConsumerState<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends ConsumerState<_StartSheet> {
  bool _byDate = false; // false = günlük hedef, true = bitiş tarihi
  int _target = 20;
  final _custom = TextEditingController();
  DateTime? _endDate;
  bool _continueFromLast = false;

  int get _startPage {
    if (!_continueFromLast) return 1;
    final p = ref.read(sharedPreferencesProvider).getInt(PrefKeys.mushafLastPage);
    return (p ?? 1).clamp(1, hatimPageTotal);
  }

  int get _effectiveTarget {
    if (_byDate && _endDate != null) {
      final days = DateTime(_endDate!.year, _endDate!.month, _endDate!.day)
          .difference(DateTime.now())
          .inDays;
      final pages = (hatimPageTotal - _startPage + 1).clamp(1, hatimPageTotal);
      return days <= 0 ? pages : (pages / days).ceil();
    }
    final custom = int.tryParse(_custom.text.trim());
    return custom != null && custom > 0 ? custom : _target;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.langCode;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('hatim.startTitle'.tr(),
                style: Theme.of(context).textTheme.titleLarge),
            const Gap.md(),
            // Mod seçimi
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: false, label: Text('hatim.byTarget'.tr())),
                ButtonSegment(value: true, label: Text('hatim.byDate'.tr())),
              ],
              selected: {_byDate},
              onSelectionChanged: (s) => setState(() => _byDate = s.first),
            ),
            const Gap.md(),
            if (!_byDate) ...[
              Text('hatim.dailyTarget'.tr(),
                  style: Theme.of(context).textTheme.titleSmall),
              const Gap.sm(),
              Wrap(
                spacing: 8,
                children: [
                  for (final v in [4, 10, 20])
                    ChoiceChip(
                      label: Text('hatim.pages'.tr(args: ['$v'])),
                      selected: _custom.text.isEmpty && _target == v,
                      onSelected: (_) => setState(() {
                        _target = v;
                        _custom.clear();
                      }),
                    ),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _custom,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'hatim.custom'.tr(),
                        filled: true,
                        fillColor: c.surfaceAlt,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.border)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text('hatim.endDate'.tr(),
                  style: Theme.of(context).textTheme.titleSmall),
              const Gap.sm(),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(_endDate == null
                    ? 'hatim.pickDate'.tr()
                    : formatGregorian(_endDate!, lang)),
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: now.add(const Duration(days: 30)),
                    firstDate: now.add(const Duration(days: 1)),
                    lastDate: now.add(const Duration(days: 366 * 3)),
                  );
                  if (d != null) setState(() => _endDate = d);
                },
              ),
              if (_endDate != null) ...[
                const Gap.sm(),
                Text(
                    'hatim.computed'.tr(args: ['$_effectiveTarget']),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.gold)),
              ],
            ],
            const Gap.md(),
            // Başlangıç sayfası
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('hatim.continueFromLast'.tr()),
              subtitle: Text('hatim.continueFromLastDesc'
                  .tr(args: ['$_startPage'])),
              value: _continueFromLast,
              activeThumbColor: c.gold,
              onChanged: (v) => setState(() => _continueFromLast = v),
            ),
            const Gap.md(),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.bg,
                  minimumSize: const Size.fromHeight(50)),
              onPressed: () async {
                await widget.parentRef
                    .read(hatimControllerProvider.notifier)
                    .start(
                      startPage: _startPage,
                      dailyTarget: _byDate ? null : _effectiveTarget,
                      targetEndDate: _byDate ? _endDate : null,
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('hatim.start'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
