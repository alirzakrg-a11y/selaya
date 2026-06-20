import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/asset_json_loader.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';

class HajjStep {
  final String type; // 'umre' | 'hac'
  final String title;
  final String desc;
  final String arabic;
  final String reading;
  const HajjStep(this.type, this.title, this.desc, this.arabic, this.reading);
  factory HajjStep.fromJson(Map<String, dynamic> j) => HajjStep(
    (j['t'] ?? '').toString(),
    (j['title'] ?? '').toString(),
    (j['desc'] ?? '').toString(),
    (j['ar'] ?? '').toString(),
    (j['rd'] ?? '').toString(),
  );
}

final hajjStepsProvider = FutureProvider<List<HajjStep>>(
  (ref) => ref
      .watch(assetJsonLoaderProvider)
      .loadModels('assets/data/hajj_umrah.json', HajjStep.fromJson),
);

/// Hac & Umre rehberi — menâsik (ibadet adımları) sırasıyla; her adımda açıklama
/// + varsa Arapça dua (niyet/telbiye) + okunuşu.
class HajjUmrahScreen extends ConsumerStatefulWidget {
  const HajjUmrahScreen({super.key});
  @override
  ConsumerState<HajjUmrahScreen> createState() => _HajjUmrahScreenState();
}

class _HajjUmrahScreenState extends ConsumerState<HajjUmrahScreen> {
  String _type = 'umre';

  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    final async = ref.watch(hajjStepsProvider);
    return SelayaScaffold(
      title: 'hajj.title'.tr(),
      showBack: true,
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (all) {
          final steps = all.where((s) => s.type == _type).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.sm,
                  AppSpacing.base,
                  AppSpacing.sm,
                ),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 'umre',
                      label: Text(tr ? 'Umre' : 'Umrah'),
                    ),
                    ButtonSegment(
                      value: 'hac',
                      label: Text(tr ? 'Hac' : 'Hajj'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
              ),
              Expanded(
                child: steps.isEmpty
                    ? const SelayaEmpty(icon: Icons.mosque_rounded)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.base,
                          0,
                          AppSpacing.base,
                          AppSpacing.xxxl,
                        ),
                        itemCount: steps.length,
                        separatorBuilder: (_, _) => const Gap.sm(),
                        itemBuilder: (_, i) =>
                            _StepCard(step: steps[i], index: i),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final HajjStep step;
  final int index;
  const _StepCard({required this.step, required this.index});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasDua = step.arabic.trim().isNotEmpty;
    return SelayaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: c.gold.withValues(alpha: 0.16),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: c.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const Gap.md(),
              Expanded(
                child: Text(
                  step.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const Gap.sm(),
          Text(
            step.desc,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
          if (hasDua) ...[
            const Gap.md(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.gold.withValues(alpha: 0.08),
                borderRadius: AppRadius.rLg,
                border: Border.all(color: c.gold.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    step.arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: AppTypography.arabic(
                      fontSize: 22,
                      color: c.textPrimary,
                    ),
                  ),
                  if (step.reading.trim().isNotEmpty) ...[
                    const Gap.sm(),
                    Text(
                      step.reading,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.gold,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
