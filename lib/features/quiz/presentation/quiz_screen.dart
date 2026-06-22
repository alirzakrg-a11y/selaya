import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../data/quiz_models.dart';

const _catLabels = <String, String>{
  'all': 'Tümü',
  'siyer': 'Siyer',
  'ibadet': 'İbadet',
  'kuran': 'Kur\'an',
  'peygamberler': 'Peygamberler',
  'genel': 'Genel',
};

enum _Phase { idle, playing, result }

/// One question prepared for a round: options are shuffled so positions can't be
/// memorised, and [correct] points at the shuffled index of the right answer.
class _SQ {
  final QuizQuestion q;
  final List<String> options;
  final int correct;
  const _SQ(this.q, this.options, this.correct);
}

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});
  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  static const _roundSize = 10;
  final _rng = Random();

  String _cat = 'all';
  _Phase _phase = _Phase.idle;
  List<_SQ> _session = const [];
  int _index = 0;
  int? _selected;
  int _correct = 0;

  void _start(List<QuizQuestion> all) {
    final pool = (_cat == 'all'
        ? List<QuizQuestion>.from(all)
        : all.where((q) => q.category == _cat).toList())
      ..shuffle(_rng);
    final picked = pool.take(_roundSize).toList();
    _session = picked.map((q) {
      final idx = List<int>.generate(q.options.length, (i) => i)..shuffle(_rng);
      return _SQ(q, [for (final i in idx) q.options[i]],
          idx.indexOf(q.correctIndex));
    }).toList();
    setState(() {
      _phase = _Phase.playing;
      _index = 0;
      _selected = null;
      _correct = 0;
    });
  }

  void _answer(int i) {
    if (_selected != null) return;
    setState(() {
      _selected = i;
      if (i == _session[_index].correct) _correct++;
    });
  }

  void _next() {
    if (_index + 1 >= _session.length) {
      ref
          .read(quizStatsProvider.notifier)
          .recordRound(correct: _correct, total: _session.length);
      setState(() => _phase = _Phase.result);
    } else {
      setState(() {
        _index++;
        _selected = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quizQuestionsProvider);
    return SelayaScaffold(
      title: 'quiz.title'.tr(),
      showBack: true,
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (all) {
          switch (_phase) {
            case _Phase.idle:
              return _Idle(
                cat: _cat,
                onCat: (c) => setState(() => _cat = c),
                onStart: () => _start(all),
              );
            case _Phase.playing:
              return _buildPlaying(context);
            case _Phase.result:
              return _buildResult(context, all);
          }
        },
      ),
    );
  }

  Widget _buildPlaying(BuildContext context) {
    final c = context.colors;
    final sq = _session[_index];
    final answered = _selected != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xxxl),
      children: [
        // İlerleme + skor
        Row(children: [
          Text('${'quiz.question'.tr()} ${_index + 1}/${_session.length}',
              style: TextStyle(
                  color: c.textSecondary, fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.check_circle_rounded, size: 16, color: c.success),
          const Gap.xs(),
          Text('$_correct', style: TextStyle(color: c.success, fontWeight: FontWeight.w800)),
        ]),
        const Gap.sm(),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (_index + (answered ? 1 : 0)) / _session.length,
            minHeight: 6,
            backgroundColor: c.border,
            valueColor: AlwaysStoppedAnimation(c.gold),
          ),
        ),
        const Gap.lg(),
        SelayaCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: c.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(_catLabels[sq.q.category] ?? sq.q.category,
                  style: TextStyle(
                      color: c.gold, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const Gap.md(),
            Text(sq.q.question,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.35)),
          ]),
        ),
        const Gap.md(),
        for (var i = 0; i < sq.options.length; i++)
          _OptionTile(
            text: sq.options[i],
            state: !answered
                ? _OptState.idle
                : i == sq.correct
                    ? _OptState.correct
                    : i == _selected
                        ? _OptState.wrong
                        : _OptState.dim,
            onTap: () => _answer(i),
          ),
        if (answered) ...[
          const Gap.md(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: (_selected == sq.correct ? c.success : c.gold)
                  .withValues(alpha: 0.10),
              borderRadius: AppRadius.rMd,
              border: Border.all(
                  color: (_selected == sq.correct ? c.success : c.gold)
                      .withValues(alpha: 0.35)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                  _selected == sq.correct
                      ? Icons.check_circle_rounded
                      : Icons.info_rounded,
                  size: 18,
                  color: _selected == sq.correct ? c.success : c.gold),
              const Gap.sm(),
              Expanded(
                child: Text(sq.q.explanation,
                    style: TextStyle(
                        color: c.textSecondary, fontSize: 13, height: 1.4)),
              ),
            ]),
          ),
          const Gap.md(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.onGold,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_index + 1 >= _session.length
                  ? 'quiz.finish'.tr()
                  : 'quiz.next'.tr()),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResult(BuildContext context, List<QuizQuestion> all) {
    final c = context.colors;
    final total = _session.length;
    final pct = total == 0 ? 0.0 : _correct / total;
    final (msg, emoji) = pct >= 0.8
        ? ('quiz.resGreat'.tr(), '🌟')
        : pct >= 0.5
            ? ('quiz.resGood'.tr(), '👍')
            : ('quiz.resTry'.tr(), '💪');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.xl, AppSpacing.base, AppSpacing.xxxl),
      children: [
        Center(child: Text(emoji, style: const TextStyle(fontSize: 56))),
        const Gap.md(),
        Center(
          child: Text('$_correct / $total',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontWeight: FontWeight.w800, color: c.gold)),
        ),
        const Gap.xs(),
        Center(
            child: Text(msg,
                style: TextStyle(color: c.textSecondary, fontSize: 15))),
        const Gap.md(),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('+${_correct * 10} ${'quiz.points'.tr()}',
                style: TextStyle(
                    color: c.success, fontWeight: FontWeight.w800)),
          ),
        ),
        const Gap.xl(),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _phase = _Phase.idle),
              style: OutlinedButton.styleFrom(
                  foregroundColor: c.gold,
                  side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text('quiz.finish'.tr()),
            ),
          ),
          const Gap.md(),
          Expanded(
            child: FilledButton(
              onPressed: () => _start(all),
              style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.onGold,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text('quiz.retry'.tr()),
            ),
          ),
        ]),
      ],
    );
  }
}

class _Idle extends ConsumerWidget {
  final String cat;
  final ValueChanged<String> onCat;
  final VoidCallback onStart;
  const _Idle({required this.cat, required this.onCat, required this.onStart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final stats = ref.watch(quizStatsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xxxl),
      children: [
        // İstatistik şeridi
        SelayaCard(
          patterned: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(children: [
            _Stat(value: '${stats.points}', label: 'quiz.points'.tr(), icon: Icons.stars_rounded),
            _Stat(value: '${stats.streak}', label: 'quiz.streak'.tr(), icon: Icons.local_fire_department_rounded),
            _Stat(value: '${stats.best}/10', label: 'quiz.best'.tr(), icon: Icons.emoji_events_rounded),
          ]),
        ),
        const Gap.lg(),
        Text('quiz.intro'.tr(),
            style: TextStyle(color: c.textSecondary, height: 1.45)),
        const Gap.lg(),
        Text('quiz.pickCategory'.tr(),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: c.gold, fontWeight: FontWeight.w700)),
        const Gap.sm(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _catLabels.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: cat == e.key,
                onSelected: (_) => onCat(e.key),
                selectedColor: c.gold.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                    color: cat == e.key ? c.gold : c.textSecondary,
                    fontWeight: FontWeight.w600),
                backgroundColor: c.surfaceAlt,
                side: BorderSide(
                    color: cat == e.key ? c.gold : c.border),
                shape: const StadiumBorder(),
              ),
          ],
        ),
        const Gap.xl(),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('quiz.start'.tr()),
            style: FilledButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: c.onGold,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _Stat({required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Column(children: [
        Icon(icon, color: c.gold, size: 22),
        const Gap.xs(),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: c.textTertiary, fontSize: 11)),
      ]),
    );
  }
}

enum _OptState { idle, correct, wrong, dim }

class _OptionTile extends StatelessWidget {
  final String text;
  final _OptState state;
  final VoidCallback onTap;
  const _OptionTile(
      {required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    late Color bg, border, fg;
    Widget? trailing;
    switch (state) {
      case _OptState.correct:
        bg = c.success.withValues(alpha: 0.14);
        border = c.success;
        fg = c.textPrimary;
        trailing = Icon(Icons.check_circle_rounded, color: c.success, size: 20);
        break;
      case _OptState.wrong:
        bg = c.danger.withValues(alpha: 0.12);
        border = c.danger;
        fg = c.textPrimary;
        trailing = Icon(Icons.cancel_rounded, color: c.danger, size: 20);
        break;
      case _OptState.dim:
        bg = c.surface;
        border = c.border;
        fg = c.textTertiary;
        break;
      case _OptState.idle:
        bg = c.surface;
        border = c.border;
        fg = c.textPrimary;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 15),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.rMd,
            border: Border.all(color: border, width: 1.4),
          ),
          child: Row(children: [
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: fg, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            if (trailing != null) ...[const Gap.sm(), trailing],
          ]),
        ),
      ),
    );
  }
}
