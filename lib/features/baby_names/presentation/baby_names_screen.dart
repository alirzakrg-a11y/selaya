import 'dart:math';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/asset_json_loader.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';

class BabyName {
  final String name;
  final String gender; // 'm' (erkek) | 'f' (kız)
  final String meaning;
  const BabyName(this.name, this.gender, this.meaning);
  factory BabyName.fromJson(Map<String, dynamic> j) => BabyName(
    (j['n'] ?? '').toString(),
    (j['g'] ?? 'm').toString(),
    (j['m'] ?? '').toString(),
  );
}

final babyNamesProvider = FutureProvider<List<BabyName>>(
  (ref) => ref
      .watch(assetJsonLoaderProvider)
      .loadModels('assets/data/baby_names.json', BabyName.fromJson),
);

/// Günün isimleri (1 erkek + 1 kız). Ana ekran "Günün İsimleri" kartı ile bu
/// ekranın günün-ismi kartı AYNI prefs anahtarlarını (baby_name_last_m/f/date)
/// paylaşır → ikisi tutarlı; yeni günde art arda aynı isim verilmez.
final dailyBabyNamesProvider =
    FutureProvider<(BabyName?, BabyName?)>((ref) async {
  final all = await ref.watch(babyNamesProvider.future);
  final prefs = ref.read(sharedPreferencesProvider);
  final n = DateTime.now();
  final today = '${n.year}-${n.month}-${n.day}';
  final males = all.where((x) => x.gender == 'm').toList();
  final females = all.where((x) => x.gender != 'm').toList();
  final lm = prefs.getString('baby_name_last_m');
  final lf = prefs.getString('baby_name_last_f');
  if (prefs.getString('baby_name_date') == today) {
    final m = males.where((x) => x.name == lm);
    final f = females.where((x) => x.name == lf);
    if (m.isNotEmpty || f.isNotEmpty) {
      return (m.isNotEmpty ? m.first : null, f.isNotEmpty ? f.first : null);
    }
  }
  BabyName? pick(List<BabyName> pool, String? exclude) {
    if (pool.isEmpty) return null;
    final p = pool.where((x) => x.name != exclude).toList();
    final src = p.isEmpty ? pool : p;
    return src[Random().nextInt(src.length)];
  }
  final m = pick(males, lm);
  final f = pick(females, lf);
  if (m != null) prefs.setString('baby_name_last_m', m.name);
  if (f != null) prefs.setString('baby_name_last_f', f.name);
  prefs.setString('baby_name_date', today);
  return (m, f);
});

/// İslami bebek isimleri: arama + cinsiyet filtresi + "günün ismi" (her gün
/// rastgele; art arda 2 gün AYNI isim verilmez — son isim prefs'te tutulur).
class BabyNamesScreen extends ConsumerStatefulWidget {
  const BabyNamesScreen({super.key});
  @override
  ConsumerState<BabyNamesScreen> createState() => _BabyNamesScreenState();
}

class _BabyNamesScreenState extends ConsumerState<BabyNamesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _gender = 'all';
  String _query = '';
  bool _favsOnly = false;
  late Set<String> _favs;
  (BabyName?, BabyName?)? _dailyPair; // günün isimleri: (erkek, kız)

  @override
  void initState() {
    super.initState();
    _favs = (ref
                .read(sharedPreferencesProvider)
                .getStringList('baby_name_favs') ??
            const <String>[])
        .toSet();
  }

  void _toggleFav(String name) {
    setState(() {
      _favs.contains(name) ? _favs.remove(name) : _favs.add(name);
    });
    ref
        .read(sharedPreferencesProvider)
        .setStringList('baby_name_favs', _favs.toList());
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Günün isimleri: bir erkek + bir kız. Yeni günse rastgele seçer (her cinste
  /// önceki günün ismini HARİÇ tutarak); aynı gün içinde sabit kalır.
  (BabyName?, BabyName?) _computeDaily(List<BabyName> all) {
    final prefs = ref.read(sharedPreferencesProvider);
    final today = _todayKey();
    final males = all.where((n) => n.gender == 'm').toList();
    final females = all.where((n) => n.gender != 'm').toList();
    final lm = prefs.getString('baby_name_last_m');
    final lf = prefs.getString('baby_name_last_f');

    // Aynı gün → kayıtlı isimleri döndür.
    if (prefs.getString('baby_name_date') == today) {
      final m = males.where((n) => n.name == lm);
      final f = females.where((n) => n.name == lf);
      if (m.isNotEmpty || f.isNotEmpty) {
        return (m.isNotEmpty ? m.first : null, f.isNotEmpty ? f.first : null);
      }
    }

    BabyName? pick(List<BabyName> pool, String? exclude) {
      if (pool.isEmpty) return null;
      final p = pool.where((n) => n.name != exclude).toList();
      final src = p.isEmpty ? pool : p;
      return src[Random().nextInt(src.length)];
    }

    final m = pick(males, lm);
    final f = pick(females, lf);
    if (m != null) prefs.setString('baby_name_last_m', m.name);
    if (f != null) prefs.setString('baby_name_last_f', f.name);
    prefs.setString('baby_name_date', today);
    return (m, f);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    final async = ref.watch(babyNamesProvider);
    return SelayaScaffold(
      title: 'babyNames.title'.tr(),
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'xt.bnmFavoritesTooltip'.tr(),
          icon: Icon(
              _favsOnly
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _favsOnly ? Colors.pink : context.colors.textTertiary),
          onPressed: () => setState(() => _favsOnly = !_favsOnly),
        ),
      ],
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (all) {
          _dailyPair ??= all.isEmpty ? (null, null) : _computeDaily(all);
          final q = _query.trim().toLowerCase();
          var list = _gender == 'all'
              ? all
              : all.where((n) => n.gender == _gender).toList();
          if (q.isNotEmpty) {
            list = list
                .where(
                  (n) =>
                      n.name.toLowerCase().contains(q) ||
                      n.meaning.toLowerCase().contains(q),
                )
                .toList();
          }
          if (_favsOnly) {
            list = list.where((n) => _favs.contains(n.name)).toList();
          }
          return Column(
            children: [
              if (_dailyPair != null &&
                  (_dailyPair!.$1 != null || _dailyPair!.$2 != null))
                _dailyCard(context, _dailyPair!, tr),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.xs,
                  AppSpacing.base,
                  AppSpacing.xs,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'xt.bnmSearchHint'.tr(),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: context.colors.textTertiary,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: context.colors.textTertiary,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    filled: true,
                    fillColor: context.colors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.rLg,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.rLg,
                      borderSide: BorderSide(
                        color: context.colors.gold,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                ),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 'all',
                      label: Text('xt.bnmFilterAll'.tr()),
                    ),
                    ButtonSegment(
                      value: 'm',
                      label: Text('xt.bnmFilterBoy'.tr()),
                      icon: const Icon(Icons.male_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: 'f',
                      label: Text('xt.bnmFilterGirl'.tr()),
                      icon: const Icon(Icons.female_rounded, size: 16),
                    ),
                  ],
                  selected: {_gender},
                  onSelectionChanged: (s) => setState(() => _gender = s.first),
                ),
              ),
              const Gap.sm(),
              Expanded(
                child: list.isEmpty
                    ? SelayaEmpty(
                        icon: _favsOnly ? Icons.favorite_border_rounded : null,
                        message: _favsOnly
                            ? 'xt.bnmNoFavorites'.tr()
                            : null)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.base,
                          0,
                          AppSpacing.base,
                          AppSpacing.xxxl,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Gap.sm(),
                        itemBuilder: (_, i) => _nameCard(context, list[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dailyCard(
      BuildContext context, (BabyName?, BabyName?) pair, bool tr) {
    final c = context.colors;
    final m = pair.$1;
    final f = pair.$2;

    Widget nameRow(BabyName n) {
      final isF = n.gender != 'm';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor:
                  (isF ? Colors.pink : c.gold).withValues(alpha: 0.16),
              child: Icon(isF ? Icons.female_rounded : Icons.male_rounded,
                  color: isF ? Colors.pink : c.gold, size: 17),
            ),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(n.meaning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textSecondary, height: 1.35)),
                ],
              ),
            ),
            InkWell(
              onTap: () => _toggleFav(n.name),
              borderRadius: BorderRadius.circular(99),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                    _favs.contains(n.name)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 19,
                    color: _favs.contains(n.name) ? Colors.pink : c.textTertiary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xs),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.gold.withValues(alpha: 0.22), c.surfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.rXl,
        border: Border.all(color: c.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('xt.bnmDailyHeader'.tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.gold,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const Gap.xs(),
          if (m != null) nameRow(m),
          if (m != null && f != null)
            Divider(height: 1, color: c.gold.withValues(alpha: 0.18)),
          if (f != null) nameRow(f),
        ],
      ),
    );
  }

  Widget _nameCard(BuildContext context, BabyName n) {
    final c = context.colors;
    final isF = n.gender == 'f';
    return SelayaCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: (isF ? Colors.pink : c.gold).withValues(
              alpha: 0.14,
            ),
            child: Icon(
              isF ? Icons.female_rounded : Icons.male_rounded,
              size: 18,
              color: isF ? Colors.pink : c.gold,
            ),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.gold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  n.meaning,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _toggleFav(n.name),
            borderRadius: BorderRadius.circular(99),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                _favs.contains(n.name)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20,
                color: _favs.contains(n.name) ? Colors.pink : c.textTertiary,
              ),
            ),
          ),
          InkWell(
            onTap: () => SharePlus.instance.share(
                ShareParams(text: '${n.name} — ${n.meaning}\n\nSELAYA')),
            borderRadius: BorderRadius.circular(99),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.ios_share_rounded,
                  size: 18, color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
