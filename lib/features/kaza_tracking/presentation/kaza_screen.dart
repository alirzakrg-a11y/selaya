import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../data/kaza_controller.dart';

class KazaScreen extends ConsumerWidget {
  const KazaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(kazaProvider);
    final ctrl = ref.read(kazaProvider.notifier);

    return SelayaScaffold(
      title: 'kaza.title'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          // total card
          SelayaCard(
            gradient: LinearGradient(colors: [
              c.gold.withValues(alpha: 0.22),
              c.surfaceAlt,
            ]),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.gold.withValues(alpha: 0.18)),
                  child: Icon(AppIcons.kerahat, color: c.gold, size: 26),
                ),
                const Gap.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('kaza.totalDebt'.tr(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.textSecondary)),
                      Text('${state.total}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: c.gold, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (state.completed > 0) ...[
            const Gap.sm(),
            SelayaCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Icon(AppIcons.check, color: c.success, size: 22),
                  const Gap.md(),
                  Expanded(
                    child: Text('kaza.completed'.tr(),
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Text('${state.completed}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: c.success, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
          const Gap.sm(),
          SelayaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('kaza.bulkTitle'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Gap.sm(),
                Row(
                  children: [
                    Expanded(
                        child: _bulkBtn(
                            context, 'kaza.addDay'.tr(), () => ctrl.addDays(1))),
                    const Gap.sm(),
                    Expanded(
                        child: _bulkBtn(context, 'kaza.addWeek'.tr(),
                            () => ctrl.addDays(7))),
                    const Gap.sm(),
                    Expanded(
                        child: _bulkBtn(context, 'kaza.addMonth'.tr(),
                            () => ctrl.addDays(30))),
                  ],
                ),
              ],
            ),
          ),
          const Gap.sm(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('kaza.desc'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.textTertiary)),
          ),
          const Gap.lg(),
          for (final key in kazaPrayers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _KazaRow(
                label: 'kaza.$key'.tr(),
                count: state.countOf(key),
                onMinus: () => ctrl.markPrayed(key),
                onPlus: () => ctrl.increment(key),
                onEdit: () => _editCount(context, ref, key, state.countOf(key)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bulkBtn(BuildContext context, String label, VoidCallback onTap) {
    final c = context.colors;
    return OutlinedButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),
      child: Text(label,
          style: TextStyle(color: c.gold, fontWeight: FontWeight.w700)),
    );
  }

  Future<void> _editCount(
      BuildContext context, WidgetRef ref, String key, int current) async {
    final controller = TextEditingController(text: current == 0 ? '' : '$current');
    try {
      final value = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('kaza.$key'.tr()),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(hintText: 'kaza.enterCount'.tr()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('common.cancel'.tr())),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(controller.text) ?? 0),
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      );
      if (value != null) {
        await ref.read(kazaProvider.notifier).setCount(key, value);
      }
    } finally {
      controller.dispose();
    }
  }
}

class _KazaRow extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onEdit;
  const _KazaRow({
    required this.label,
    required this.count,
    required this.onMinus,
    required this.onPlus,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.titleSmall),
          ),
          _RoundBtn(icon: AppIcons.remove, onTap: onMinus),
          GestureDetector(
            onTap: onEdit,
            child: SizedBox(
              width: 56,
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: c.gold, fontWeight: FontWeight.w700)),
            ),
          ),
          _RoundBtn(icon: AppIcons.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, size: 18, color: c.gold),
      ),
    );
  }
}
