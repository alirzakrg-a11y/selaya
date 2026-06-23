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

/// Bu haftanın liderlik tablosu — 1./2./3. madalyalı, kendi sıran vurgulu.
class QuizLeaderboardScreen extends ConsumerWidget {
  const QuizLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(quizLeaderboardProvider);
    final loggedIn = ref.watch(authControllerProvider).user != null;
    return SelayaScaffold(
      title: 'quiz.leaderboard'.tr(),
      showBack: true,
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: c.gold),
          onPressed: () => ref.invalidate(quizLeaderboardProvider),
        ),
      ],
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (lb) => ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xxxl),
          children: [
            Row(children: [
              Icon(Icons.emoji_events_rounded, color: c.gold, size: 20),
              const Gap.sm(),
              Text('${'quiz.weekOf'.tr()} ${lb.week}',
                  style: TextStyle(
                      color: c.textSecondary, fontWeight: FontWeight.w600)),
            ]),
            const Gap.md(),
            if (lb.myRank != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: c.gold.withValues(alpha: 0.12),
                  borderRadius: AppRadius.rMd,
                  border: Border.all(color: c.gold.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  Icon(Icons.person_rounded, color: c.gold),
                  const Gap.sm(),
                  Expanded(
                    child: Text('quiz.yourRank'.tr(args: ['${lb.myRank}']),
                        style: TextStyle(
                            color: c.textPrimary, fontWeight: FontWeight.w700)),
                  ),
                  Text('${lb.myScore ?? 0}',
                      style: TextStyle(
                          color: c.gold, fontWeight: FontWeight.w800)),
                ]),
              ),
            if (lb.top.isEmpty)
              SelayaEmpty(
                icon: Icons.emoji_events_outlined,
                message: 'quiz.emptyBoard'.tr(),
              )
            else
              for (var i = 0; i < lb.top.length; i++)
                _row(context, i + 1, lb.top[i]),
            if (!loggedIn) ...[
              const Gap.md(),
              SelayaCard(
                onTap: () => context.push(Routes.auth),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(children: [
                  Icon(Icons.login_rounded, color: c.gold),
                  const Gap.sm(),
                  Expanded(
                    child: Text('quiz.signInToRank'.tr(),
                        style: TextStyle(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int rank, LeaderEntry e) {
    final c = context.colors;
    final medal = rank == 1
        ? const Color(0xFFFFD24A)
        : rank == 2
            ? const Color(0xFFC7CBD1)
            : rank == 3
                ? const Color(0xFFCE8A4E)
                : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 13),
        decoration: BoxDecoration(
          color: medal != null
              ? medal.withValues(alpha: 0.10)
              : c.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(
              color: medal != null
                  ? medal.withValues(alpha: 0.5)
                  : c.border),
        ),
        child: Row(children: [
          SizedBox(
            width: 34,
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, color: medal, size: 24)
                : Text('$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: c.textTertiary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
          ),
          const Gap.sm(),
          Expanded(
            child: Text('@${e.rumuz}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
          Text('${e.correct}/${e.total}',
              style: TextStyle(color: c.textTertiary, fontSize: 12)),
          const Gap.md(),
          Text('${e.score}',
              style: TextStyle(
                  color: c.gold, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      ),
    );
  }
}
