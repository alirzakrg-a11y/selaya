import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../auth/data/auth_controller.dart';
import '../data/quiz_api.dart';
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

enum _Mode { practice, weekly }

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
  static const _practiceSize = 10;
  static const _weeklySize = 15;
  static const _seconds = 10;
  final _rng = Random();

  String _cat = 'all';
  _Phase _phase = _Phase.idle;
  _Mode _mode = _Mode.practice;
  List<_SQ> _session = const [];
  int _index = 0;
  int? _selected; // null = cevaplanmadı, -1 = süre doldu, 0..3 = seçilen
  int _correct = 0;
  int _score = 0; // haftalık puan (hız bonuslu)
  int _secondsLeft = _seconds;
  Timer? _timer;
  bool _submitting = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _onTimeout();
      }
    });
  }

  void _start(List<QuizQuestion> all, _Mode mode) {
    final week = quizWeekKey();
    List<QuizQuestion> picked;
    Random optRng;
    if (mode == _Mode.weekly) {
      picked = weeklyQuestions(all, week, _weeklySize);
      optRng = Random(weekSeed(week)); // herkese aynı sorular + şık sırası
    } else {
      final pool = (_cat == 'all'
          ? List<QuizQuestion>.from(all)
          : all.where((q) => q.category == _cat).toList())
        ..shuffle(_rng);
      picked = pool.take(_practiceSize).toList();
      optRng = _rng;
    }
    _session = picked.map((q) {
      final idx = List<int>.generate(q.options.length, (i) => i)
        ..shuffle(optRng);
      return _SQ(q, [for (final i in idx) q.options[i]],
          idx.indexOf(q.correctIndex));
    }).toList();
    setState(() {
      _mode = mode;
      _phase = _Phase.playing;
      _index = 0;
      _selected = null;
      _correct = 0;
      _score = 0;
    });
    _startTimer();
  }

  void _answer(int i) {
    if (_selected != null) return;
    _timer?.cancel();
    setState(() {
      _selected = i;
      if (i == _session[_index].correct) {
        _correct++;
        if (_mode == _Mode.weekly) _score += 100 + _secondsLeft * 5;
      }
    });
  }

  void _onTimeout() {
    if (_selected != null) return;
    setState(() => _selected = -1);
  }

  Future<void> _next() async {
    if (_index + 1 >= _session.length) {
      _timer?.cancel();
      await ref
          .read(quizStatsProvider.notifier)
          .recordRound(correct: _correct, total: _session.length);
      if (_mode == _Mode.weekly) await _submitWeekly();
      if (mounted) setState(() => _phase = _Phase.result);
    } else {
      setState(() {
        _index++;
        _selected = null;
      });
      _startTimer();
    }
  }

  Future<void> _submitWeekly() async {
    final auth = ref.read(authControllerProvider);
    if (auth.token == null || auth.user == null) return;
    setState(() => _submitting = true);
    try {
      await QuizApi.submit(auth.token!, _score, _correct, _session.length);
      ref.invalidate(quizLeaderboardProvider);
    } catch (_) {}
    if (mounted) setState(() => _submitting = false);
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
                onCat: (v) => setState(() => _cat = v),
                onWeekly: () => _start(all, _Mode.weekly),
                onPractice: () => _start(all, _Mode.practice),
                onLeaderboard: () => context.push(Routes.quizLeaderboard),
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
    final low = _secondsLeft <= 3;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xxxl),
      children: [
        Row(children: [
          Text('${'quiz.question'.tr()} ${_index + 1}/${_session.length}',
              style: TextStyle(
                  color: c.textSecondary, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_mode == _Mode.weekly) ...[
            Icon(Icons.stars_rounded, size: 16, color: c.gold),
            const Gap.xs(),
            Text('$_score',
                style:
                    TextStyle(color: c.gold, fontWeight: FontWeight.w800)),
            const Gap.md(),
          ],
          Icon(Icons.check_circle_rounded, size: 16, color: c.success),
          const Gap.xs(),
          Text('$_correct',
              style:
                  TextStyle(color: c.success, fontWeight: FontWeight.w800)),
        ]),
        const Gap.md(),
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
        const Gap.sm(),
        // Geri sayım — sorunun ALTINDA
        Row(children: [
          Icon(Icons.timer_outlined,
              size: 16, color: low ? c.danger : c.textSecondary),
          const Gap.xs(),
          Text('$_secondsLeft sn',
              style: TextStyle(
                  color: low ? c.danger : c.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const Gap.sm(),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: answered ? 0 : _secondsLeft / _seconds,
                minHeight: 6,
                backgroundColor: c.border,
                valueColor: AlwaysStoppedAnimation(low ? c.danger : c.gold),
              ),
            ),
          ),
        ]),
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
                      : _selected == -1
                          ? Icons.timer_off_rounded
                          : Icons.info_rounded,
                  size: 18,
                  color: _selected == sq.correct ? c.success : c.gold),
              const Gap.sm(),
              Expanded(
                child: Text(
                    _selected == -1
                        ? '${'quiz.timeUp'.tr()} ${sq.q.explanation}'
                        : sq.q.explanation,
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
    final weekly = _mode == _Mode.weekly;
    final loggedIn = ref.watch(authControllerProvider).user != null;
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
            child: Text(
                weekly
                    ? '${'quiz.weeklyScore'.tr()}: $_score'
                    : '+${_correct * 10} ${'quiz.points'.tr()}',
                style:
                    TextStyle(color: c.success, fontWeight: FontWeight.w800)),
          ),
        ),
        if (weekly && _submitting) ...[
          const Gap.md(),
          Center(
              child: Text('quiz.submitting'.tr(),
                  style: TextStyle(color: c.textTertiary, fontSize: 13))),
        ],
        if (weekly && !loggedIn) ...[
          const Gap.md(),
          Center(
            child: Text('quiz.signInToRank'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textTertiary, fontSize: 13)),
          ),
        ],
        const Gap.xl(),
        if (weekly)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(Routes.quizLeaderboard),
              icon: const Icon(Icons.emoji_events_rounded, size: 18),
              label: Text('quiz.seeLeaderboard'.tr()),
              style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.onGold,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        const Gap.md(),
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
              onPressed: () => _start(all, _mode),
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
  final VoidCallback onWeekly;
  final VoidCallback onPractice;
  final VoidCallback onLeaderboard;
  const _Idle({
    required this.cat,
    required this.onCat,
    required this.onWeekly,
    required this.onPractice,
    required this.onLeaderboard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final stats = ref.watch(quizStatsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xxxl),
      children: [
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
        // HAFTALIK YARIŞMA
        SelayaCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.emoji_events_rounded, color: c.gold),
              const Gap.sm(),
              Text('quiz.weekly'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            const Gap.sm(),
            Text('quiz.weeklyDesc'.tr(),
                style: TextStyle(color: c.textSecondary, height: 1.4, fontSize: 13)),
            const Gap.md(),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onWeekly,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text('quiz.startWeekly'.tr()),
                  style: FilledButton.styleFrom(
                      backgroundColor: c.gold,
                      foregroundColor: c.onGold,
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                ),
              ),
              const Gap.sm(),
              IconButton.outlined(
                onPressed: onLeaderboard,
                icon: Icon(Icons.leaderboard_rounded, color: c.gold),
                tooltip: 'quiz.leaderboard'.tr(),
              ),
            ]),
          ]),
        ),
        const Gap.lg(),
        // PRATİK
        Text('quiz.practice'.tr(),
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
                side: BorderSide(color: cat == e.key ? c.gold : c.border),
                shape: const StadiumBorder(),
              ),
          ],
        ),
        const Gap.md(),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPractice,
            icon: const Icon(Icons.school_rounded, size: 18),
            label: Text('quiz.startPractice'.tr()),
            style: OutlinedButton.styleFrom(
                foregroundColor: c.gold,
                side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 13)),
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
