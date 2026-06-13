import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../data/featured_tools.dart';

/// "Öne Çıkanlar İçeriği" — kullanıcı ızgarada hangi araçların görüneceğini
/// seçer (anahtar) ve sürükleyerek sıralar. Anında ana ekrana yansır.
class FeaturedGridScreen extends ConsumerWidget {
  const FeaturedGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = ref.watch(featuredToolsProvider);
    final ctrl = ref.read(featuredToolsProvider.notifier);
    return SelayaScaffold(
      title: 'featuredEdit.title'.tr(),
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'common.reset'.tr(),
          icon: Icon(Icons.restore_rounded, color: c.gold),
          onPressed: ctrl.reset,
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
            child: Text('featuredEdit.desc'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.textSecondary)),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base, 0, AppSpacing.base, AppSpacing.xxxl),
              itemCount: t.order.length,
              // onReorderItem: yeni API newIndex'i kaldırılan öğe için ZATEN
              // ayarlar — controller'daki eski `newIndex -= 1` düzeltmesi kalktı.
              onReorderItem: ctrl.reorder,
              itemBuilder: (context, i) {
                final key = t.order[i];
                final tool = featuredTools[key];
                return Container(
                  key: ValueKey(key),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.only(left: AppSpacing.base),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: AppRadius.rMd,
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Icon(Icons.drag_indicator_rounded,
                              color: c.gold),
                        ),
                      ),
                      const Gap.sm(),
                      if (tool != null)
                        Icon(tool.icon, size: 20, color: c.gold),
                      const Gap.sm(),
                      Expanded(
                        child: Text((tool?.labelKey ?? key).tr(),
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      Switch(
                        value: t.isVisible(key),
                        onChanged: (_) => ctrl.toggle(key),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
