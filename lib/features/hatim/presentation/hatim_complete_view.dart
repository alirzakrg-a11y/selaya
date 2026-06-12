import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/share/share_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confetti_overlay.dart';
import '../../../core/widgets/selaya_card.dart';
import '../data/hatim_controller.dart';
import '../domain/hatim_session.dart';
import 'hatim_screen.dart' show openMushafAt;

/// Hatim tamamlanınca gösterilen kutlama. Paylaşılabilir kart mevcut paylaşım
/// sayfası altyapısını kullanır (panel duvar kâğıdı arka planı + SELAYA logosu).
class HatimCompleteView extends ConsumerStatefulWidget {
  final HatimSession session;
  const HatimCompleteView({super.key, required this.session});

  @override
  ConsumerState<HatimCompleteView> createState() => _HatimCompleteViewState();
}

class _HatimCompleteViewState extends ConsumerState<HatimCompleteView> {
  @override
  void initState() {
    super.initState();
    // 🎆 Açılışta kutlama.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) celebrate(context);
    });
  }

  String get _shareText {
    final days = widget.session.dayCount;
    return context.langCode == 'tr'
        ? '$days günde hatmimi tamamladım, elhamdülillah 🤲'
        : 'I completed my Quran khatm in $days days, alhamdulillah 🤲';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.session;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.xl, AppSpacing.base, AppSpacing.xxxl),
      children: [
        Icon(Icons.verified_rounded, size: 84, color: c.success),
        const Gap.md(),
        Text('hatim.completeTitle'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const Gap.sm(),
        Text('hatim.completeBody'.tr(args: ['${s.dayCount}']),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: c.textSecondary)),
        const Gap.xl(),
        // startPage > 1 ise: kalan baş sayfaları okuma önerisi (yeni oturum
        // BAŞLATMAZ, sadece mushafa yönlendirir).
        if (s.startPage > 1) ...[
          SelayaCard(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('hatim.readRestTitle'.tr(),
                    style: Theme.of(context).textTheme.titleSmall),
                const Gap.xs(),
                Text(
                    'hatim.readRestBody'.tr(args: ['${s.startPage - 1}']),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary)),
                const Gap.sm(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_stories_rounded, size: 18),
                  label: Text('hatim.readRestCta'.tr()),
                  onPressed: () => openMushafAt(context, 1),
                ),
              ],
            ),
          ),
          const Gap.md(),
        ],
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: c.gold,
              foregroundColor: c.bg,
              minimumSize: const Size.fromHeight(50)),
          icon: const Icon(Icons.share_rounded),
          label: Text('hatim.share'.tr()),
          onPressed: () => showVerseShareSheet(
            context,
            text: _shareText,
            reference: 'SELAYA',
            label: 'hatim.title'.tr(),
          ),
        ),
        const Gap.sm(),
        TextButton(
          onPressed: () =>
              ref.read(hatimControllerProvider.notifier).archiveCompleted(),
          child: Text('common.done'.tr()),
        ),
      ],
    );
  }
}
