import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/asset_json_loader.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';

class IlmihalItem {
  final String category;
  final String question;
  final String answer;
  const IlmihalItem(this.category, this.question, this.answer);
  factory IlmihalItem.fromJson(Map<String, dynamic> j) => IlmihalItem(
    (j['c'] ?? '').toString(),
    (j['q'] ?? '').toString(),
    (j['a'] ?? '').toString(),
  );
}

final ilmihalProvider = FutureProvider<List<IlmihalItem>>(
  (ref) => ref
      .watch(assetJsonLoaderProvider)
      .loadModels('assets/data/ilmihal.json', IlmihalItem.fromJson),
);

/// İlmihal — temel fıkıh bilgileri + sık sorulan dini sorular. Kategorilere
/// göre gruplu, açılır-kapanır soru-cevap + arama.
class IlmihalScreen extends ConsumerStatefulWidget {
  const IlmihalScreen({super.key});
  @override
  ConsumerState<IlmihalScreen> createState() => _IlmihalScreenState();
}

class _IlmihalScreenState extends ConsumerState<IlmihalScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    final c = context.colors;
    final async = ref.watch(ilmihalProvider);
    return SelayaScaffold(
      title: 'ilmihal.title'.tr(),
      showBack: true,
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (all) {
          final q = _query.trim().toLowerCase();
          final list = q.isEmpty
              ? all
              : all
                    .where(
                      (e) =>
                          e.question.toLowerCase().contains(q) ||
                          e.answer.toLowerCase().contains(q),
                    )
                    .toList();
          String? prevCat;
          final children = <Widget>[];
          for (final e in list) {
            if (e.category != prevCat) {
              prevCat = e.category;
              children.add(
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 14, bottom: 6),
                  child: Text(
                    e.category,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: c.gold,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }
            children.add(_QaCard(item: e));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.sm,
                  AppSpacing.base,
                  AppSpacing.xs,
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: tr ? 'Soru ara…' : 'Search…',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: c.textTertiary,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: c.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.rLg,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: children.isEmpty
                    ? const SelayaEmpty()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.base,
                          0,
                          AppSpacing.base,
                          AppSpacing.xxxl,
                        ),
                        children: children,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QaCard extends StatelessWidget {
  final IlmihalItem item;
  const _QaCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: AppRadius.rLg,
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: c.gold,
            collapsedIconColor: c.textTertiary,
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            leading: Icon(Icons.help_outline_rounded, color: c.gold, size: 20),
            title: Text(
              item.question,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.answer,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
