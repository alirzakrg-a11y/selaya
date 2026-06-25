import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/asset_json_loader.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
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

/// İlmihal — temel fıkıh bilgileri + sık sorulan dini sorular. Kategori
/// filtresi + arama + açılır-kapanır soru-cevap.
class IlmihalScreen extends ConsumerStatefulWidget {
  const IlmihalScreen({super.key});
  @override
  ConsumerState<IlmihalScreen> createState() => _IlmihalScreenState();
}

class _IlmihalScreenState extends ConsumerState<IlmihalScreen> {
  String _query = '';
  String _category = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Kategoriler (veri sırasında, başa "all").
          final cats = <String>['all'];
          for (final e in all) {
            if (!cats.contains(e.category)) cats.add(e.category);
          }
          // Arama varsa TÜM kategoride ara; yoksa seçili kategori.
          var list = q.isNotEmpty
              ? all
              : (_category == 'all'
                  ? all
                  : all.where((e) => e.category == _category).toList());
          if (q.isNotEmpty) {
            list = list
                .where((e) =>
                    e.question.toLowerCase().contains(q) ||
                    e.answer.toLowerCase().contains(q))
                .toList();
          }

          // Kategori başlıklarıyla grupla + sonuna kaynak notu.
          String? prevCat;
          final children = <Widget>[];
          // Varsayılan görünümde (arama/filtre yokken) altın tanıtım başlığı.
          if (q.isEmpty && _category == 'all') {
            children.add(_IlmihalHero(count: all.length));
            children.add(const Gap.md());
          }
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
          if (children.isNotEmpty) {
            children.add(const Gap.md());
            children.add(const _SourceNote());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                    AppSpacing.sm, AppSpacing.base, AppSpacing.xs),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'xt.ilSearchHint'.tr(),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 20, color: c.textTertiary),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 19, color: c.textTertiary),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: c.surfaceAlt,
                    border: OutlineInputBorder(
                        borderRadius: AppRadius.rLg,
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.rLg,
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.rLg,
                        borderSide: BorderSide(color: c.gold, width: 1.4)),
                  ),
                ),
              ),
              // Kategori filtre çipleri (arama yokken etkin).
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                  itemCount: cats.length,
                  separatorBuilder: (_, _) => const Gap.sm(),
                  itemBuilder: (_, i) {
                    final cat = cats[i];
                    return _CatChip(
                      label: cat == 'all' ? 'xt.ilCatAll'.tr() : cat,
                      selected: _category == cat && _query.isEmpty,
                      onTap: () => setState(() {
                        _category = cat;
                        if (_query.isNotEmpty) {
                          _searchCtrl.clear();
                          _query = '';
                        }
                      }),
                    );
                  },
                ),
              ),
              const Gap.sm(),
              Expanded(
                child: children.isEmpty
                    ? SelayaEmpty(
                        message:
                            'xt.ilNoResults'.tr(args: [_query.trim()]))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0,
                            AppSpacing.base, AppSpacing.xxxl),
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

/// Altın gradyanlı tanıtım başlığı (soru sayısı + kaynak).
class _IlmihalHero extends StatelessWidget {
  final int count;
  const _IlmihalHero({required this.count});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      gradient: LinearGradient(colors: c.goldGradient),
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, color: c.onGold, size: 28),
          const Gap.base(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('xt.ilHeroTitle'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: c.onGold, fontWeight: FontWeight.w800)),
                const Gap.xxs(),
                Text(
                    'xt.ilHeroSubtitle'.tr(args: [count.toString()]),
                    style: TextStyle(
                        color: c.onGold.withValues(alpha: 0.78), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? c.gold : c.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: selected ? c.gold : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.onGold : c.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.gold.withValues(alpha: 0.08),
        borderRadius: AppRadius.rSm,
        border: Border.all(color: c.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, size: 16, color: c.gold),
          const Gap.sm(),
          Expanded(
            child: Text(
              'xt.ilSourceNote'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textSecondary, height: 1.4),
            ),
          ),
        ],
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
