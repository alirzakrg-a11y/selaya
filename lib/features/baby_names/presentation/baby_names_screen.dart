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
  BabyName? _daily; // bir kez hesaplanır (oturum içinde sabit)

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

  /// Günün ismini döndürür; yeni günse rastgele seçer (öncekini HARİÇ tutarak).
  BabyName _computeDaily(List<BabyName> all) {
    final prefs = ref.read(sharedPreferencesProvider);
    final today = _todayKey();
    final lastName = prefs.getString('baby_name_last');
    if (prefs.getString('baby_name_date') == today && lastName != null) {
      final m = all.where((n) => n.name == lastName);
      if (m.isNotEmpty) return m.first;
    }
    final pool = all.where((n) => n.name != lastName).toList();
    final src = pool.isEmpty ? all : pool;
    final pick = src[Random().nextInt(src.length)];
    prefs.setString('baby_name_last', pick.name);
    prefs.setString('baby_name_date', today);
    return pick;
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
          tooltip: tr ? 'Favoriler' : 'Favorites',
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
          _daily ??= all.isEmpty ? null : _computeDaily(all);
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
              if (_daily != null) _dailyCard(context, _daily!, tr),
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
                    hintText: tr
                        ? 'İsim veya anlam ara'
                        : 'Search name or meaning',
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
                      label: Text(tr ? 'Hepsi' : 'All'),
                    ),
                    ButtonSegment(
                      value: 'm',
                      label: Text(tr ? 'Erkek' : 'Boy'),
                      icon: const Icon(Icons.male_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: 'f',
                      label: Text(tr ? 'Kız' : 'Girl'),
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
                            ? (tr
                                ? 'Henüz favori isim yok.\nBeğendiğin ismi ♡ ile ekle.'
                                : 'No favorite names yet.')
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

  Widget _dailyCard(BuildContext context, BabyName n, bool tr) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.gold.withValues(alpha: 0.22), c.surfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.rXl,
        border: Border.all(color: c.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            n.gender == 'f' ? Icons.female_rounded : Icons.male_rounded,
            color: c.gold,
            size: 30,
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr ? 'Günün İsmi' : 'Name of the Day',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.gold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  n.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  n.meaning,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
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
