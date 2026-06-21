import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../data/home_layout_controller.dart';

/// Her bölüm için liste ikonu — düzenleme ekranında tanınırlığı artırır.
const _sectionIcons = <String, IconData>{
  'storyRail': Icons.auto_stories_rounded,
  'greeting': Icons.waving_hand_rounded,
  'religiousDay': Icons.event_rounded,
  'gaugeCarousel': Icons.timer_outlined,
  'prayerStrip': Icons.mosque_rounded,
  'nearestMosque': Icons.location_on_rounded,
  'featured': Icons.grid_view_rounded,
  'quickPair': Icons.bolt_rounded,
  'verseHadithPair': Icons.menu_book_rounded,
  'dailyDua': Icons.volunteer_activism_rounded,
  'mediaPair': Icons.play_circle_outline_rounded,
  'widgetPromo': Icons.widgets_rounded,
  'ai': Icons.auto_awesome_rounded,
};

/// "Ana Ekranı Düzenle" — kullanıcı bölümleri sürükleyerek sıralar ve
/// anahtarla gizler/gösterir. Değişiklikler anında ana ekrana yansır.
class HomeLayoutScreen extends ConsumerWidget {
  const HomeLayoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final layout = ref.watch(homeLayoutProvider);
    final ctrl = ref.read(homeLayoutProvider.notifier);
    final visibleCount = layout.order.where(layout.isVisible).length;
    return SelayaScaffold(
      title: 'homeLayout.title'.tr(),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('homeLayout.desc'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textSecondary)),
                ),
                const Gap.sm(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('$visibleCount / ${layout.order.length}',
                      style: TextStyle(
                          color: c.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
            child: OutlinedButton.icon(
              onPressed: () => context.push(Routes.featuredEdit),
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: Text('featuredEdit.title'.tr()),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
                foregroundColor: c.gold,
                shape:
                    const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base, 0, AppSpacing.base, AppSpacing.xxxl),
              itemCount: layout.order.length,
              onReorder: ctrl.reorder,
              itemBuilder: (context, i) {
                final key = layout.order[i];
                final visible = layout.isVisible(key);
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
                              color: c.textTertiary),
                        ),
                      ),
                      const Gap.sm(),
                      Icon(_sectionIcons[key] ?? Icons.tune_rounded,
                          size: 19,
                          color: visible ? c.gold : c.textTertiary),
                      const Gap.md(),
                      Expanded(
                        child: Text((homeSectionLabels[key] ?? key).tr(),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    color: visible ? null : c.textTertiary,
                                    fontWeight: visible
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                      ),
                      Switch(
                        value: visible,
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
