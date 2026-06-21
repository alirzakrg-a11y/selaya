import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/overpass_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../data/mosque_repository.dart';
import 'mosque_guide_sheet.dart';

const _featureFilters = ['historic', 'disabled', 'women', 'quranCourse', 'selatin'];

String _distLabel(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

Future<void> _openDirections({String? query, double? lat, double? lng}) async {
  final Uri uri = (lat != null && lng != null)
      ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')
      : Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query ?? '')}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class MosquesScreen extends StatelessWidget {
  const MosquesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DefaultTabController(
      length: 2,
      child: SelayaScaffold(
        title: 'mosques.title'.tr(),
        showBack: true,
        actions: [
          IconButton(
            tooltip: context.langCode == 'tr'
                ? 'Cami adabı & duaları'
                : 'Mosque etiquette',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => showMosqueGuideSheet(context),
          ),
        ],
        body: Column(
          children: [
            TabBar(
              labelColor: c.gold,
              unselectedLabelColor: c.textTertiary,
              indicatorColor: c.gold,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(text: 'mosques.nearbyTab'.tr()),
                Tab(text: 'mosques.guideTab'.tr()),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [_NearbyTab(), _GuideTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Nearby (GPS + OSM) ───────────────────────────

class _NearbyTab extends ConsumerStatefulWidget {
  const _NearbyTab();
  @override
  ConsumerState<_NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends ConsumerState<_NearbyTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = false;
  bool _denied = false;
  List<NearbyMosque>? _results;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _find());
  }

  Future<void> _find() async {
    setState(() {
      _loading = true;
      _denied = false;
    });
    final loc = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    if (loc == null) {
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }
    final list = await ref.read(overpassServiceProvider).findNearby(loc);
    if (!mounted) return;
    setState(() {
      _results = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.colors;

    if (_loading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SelayaLoading(),
          const Gap.md(),
          Text('settings.locating'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textTertiary)),
        ],
      );
    }

    if (_denied || _results == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.location, size: 44, color: c.gold),
              const Gap.base(),
              Text('mosques.nearbyHint'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.textSecondary)),
              const Gap.lg(),
              GradientButton(
                label: 'mosques.findNearby'.tr(),
                icon: AppIcons.location,
                onPressed: _find,
              ),
            ],
          ),
        ),
      );
    }

    final results = _results!;
    if (results.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SelayaEmpty(message: 'mosques.nearbyEmpty'.tr(), icon: AppIcons.mosque),
          const Gap.md(),
          GhostButton(
              label: 'common.retry'.tr(), icon: AppIcons.refresh, onPressed: _find),
        ],
      );
    }

    return RefreshIndicator(
      color: c.gold,
      onRefresh: _find,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xxxl),
        itemCount: results.length + 1,
        separatorBuilder: (_, _) => const Gap.sm(),
        itemBuilder: (context, i) {
          if (i == results.length) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text('mosques.osm'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: c.textTertiary)),
            );
          }
          return _NearbyTile(mosque: results[i]);
        },
      ),
    );
  }
}

class _NearbyTile extends StatelessWidget {
  final NearbyMosque mosque;
  const _NearbyTile({required this.mosque});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: () =>
          _openDirections(lat: mosque.lat, lng: mosque.lng),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.gold.withValues(alpha: 0.12),
            ),
            child: const Icon(AppIcons.mosque, color: AppColors.gold, size: 20),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mosque.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                Row(
                  children: [
                    Icon(AppIcons.location, size: 13, color: c.gold),
                    const SizedBox(width: 3),
                    Text(_distLabel(mosque.distanceKm),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: c.gold)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.directions_rounded),
            color: c.gold,
            onPressed: () => _openDirections(lat: mosque.lat, lng: mosque.lng),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Province guide (Diyanet) ───────────────────────────

class _GuideTab extends ConsumerStatefulWidget {
  const _GuideTab();
  @override
  ConsumerState<_GuideTab> createState() => _GuideTabState();
}

class _GuideTabState extends ConsumerState<_GuideTab>
    with AutomaticKeepAliveClientMixin {
  String? _slug;
  String _district = 'all';
  String _query = '';
  final Set<String> _filters = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _defaultSlug(List<Province> provs, String? cityName) {
    if (cityName != null) {
      final norm = cityName.toLowerCase();
      final match = provs.where((p) => p.name.toLowerCase() == norm);
      if (match.isNotEmpty) return match.first.slug;
    }
    final ist = provs.where((p) => p.slug == 'istanbul');
    return ist.isNotEmpty ? ist.first.slug : provs.first.slug;
  }

  bool _passes(Mosque m) {
    for (final f in _filters) {
      final ok = switch (f) {
        'historic' => m.historic,
        'selatin' => m.selatin,
        'disabled' => m.disabledAccess,
        'women' => m.womenArea,
        'quranCourse' => m.quranCourse,
        _ => true,
      };
      if (!ok) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.colors;
    final lang = context.langCode;
    final provincesAsync = ref.watch(mosqueProvincesProvider);
    final cityName = ref.watch(selectedCityProvider).value?.name(lang);

    return provincesAsync.when(
      loading: () => const SelayaLoading(),
      error: (e, _) => SelayaError(error: e),
      data: (provinces) {
        final slug = _slug ??= _defaultSlug(provinces, cityName);
        final province =
            provinces.firstWhere((p) => p.slug == slug, orElse: () => provinces.first);
        final mosquesAsync = ref.watch(provinceMosquesProvider(slug));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _SelectorButton(
                      icon: AppIcons.location,
                      label: 'mosques.province'.tr(),
                      value: '${province.name} (${province.count})',
                      onTap: () => _pickProvince(provinces),
                    ),
                  ),
                  const Gap.sm(),
                  Expanded(
                    child: _SelectorButton(
                      icon: AppIcons.mosque,
                      label: 'mosques.district'.tr(),
                      value: _district == 'all'
                          ? 'mosques.allDistricts'.tr()
                          : _district,
                      onTap: () {
                        final list = mosquesAsync.value;
                        if (list != null) _pickDistrict(list);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: AppSpacing.sm),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'mosques.search'.tr(),
                  prefixIcon: const Icon(AppIcons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 12),
                  filled: true,
                  fillColor: c.surfaceAlt,
                  border: OutlineInputBorder(
                      borderRadius: AppRadius.rLg,
                      borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.rLg,
                      borderSide: BorderSide(color: c.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.rLg,
                      borderSide: BorderSide(color: c.gold, width: 1.4)),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.screen,
                children: [
                  for (final f in _featureFilters)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: FilterChip(
                        label: Text('mosques.$f'.tr()),
                        selected: _filters.contains(f),
                        onSelected: (s) => setState(
                            () => s ? _filters.add(f) : _filters.remove(f)),
                        selectedColor: c.gold.withValues(alpha: 0.2),
                        backgroundColor: c.surfaceAlt,
                        checkmarkColor: c.gold,
                        labelStyle: TextStyle(
                            color: _filters.contains(f) ? c.gold : c.textSecondary,
                            fontSize: 13),
                        side: BorderSide(
                            color: _filters.contains(f)
                                ? c.gold.withValues(alpha: 0.5)
                                : c.border),
                      ),
                    ),
                ],
              ),
            ),
            const Gap.sm(),
            Expanded(
              child: mosquesAsync.when(
                loading: () => const SelayaLoading(),
                error: (e, _) => SelayaError(error: e),
                data: (all) {
                  final q = _query.toLowerCase();
                  final list = all.where((m) {
                    if (_district != 'all' && m.district != _district) return false;
                    if (q.isNotEmpty && !m.name.toLowerCase().contains(q)) return false;
                    return _passes(m);
                  }).toList();
                  if (list.isEmpty) return SelayaEmpty(message: 'mosques.empty'.tr());
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.base, 0, AppSpacing.base, AppSpacing.xxxl),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, _) => const Gap.sm(),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text('mosques.count'.tr(args: ['${list.length}']),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: c.textTertiary)),
                        );
                      }
                      return _MosqueTile(
                        mosque: list[i - 1],
                        onTap: () => _showDetail(list[i - 1], province.name),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _pickProvince(List<Province> provinces) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProvinceSheet(
        provinces: provinces,
        onSelected: (p) => setState(() {
          _slug = p.slug;
          _district = 'all';
          _query = '';
          _searchController.clear();
          _filters.clear();
        }),
      ),
    );
  }

  void _pickDistrict(List<Mosque> mosques) {
    final districts = mosques.map((m) => m.district).toSet().toList()..sort();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text('mosques.allDistricts'.tr()),
              trailing: _district == 'all'
                  ? Icon(AppIcons.check, color: context.colors.gold)
                  : null,
              onTap: () {
                setState(() => _district = 'all');
                Navigator.pop(context);
              },
            ),
            for (final d in districts)
              ListTile(
                title: Text(d),
                trailing: _district == d
                    ? Icon(AppIcons.check, color: context.colors.gold)
                    : null,
                onTap: () {
                  setState(() => _district = d);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDetail(Mosque m, String province) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MosqueDetailSheet(mosque: m, province: province),
    );
  }
}

class _SelectorButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _SelectorButton(
      {required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.gold),
          const Gap.sm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: c.textTertiary)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
          Icon(Icons.expand_more_rounded, size: 18, color: c.textTertiary),
        ],
      ),
    );
  }
}

class _MosqueTile extends StatelessWidget {
  final Mosque mosque;
  final VoidCallback onTap;
  const _MosqueTile({required this.mosque, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (mosque.historic ? c.gold : c.textSecondary)
                  .withValues(alpha: 0.12),
            ),
            child: Icon(
                mosque.historic ? Icons.account_balance_rounded : AppIcons.mosque,
                color: mosque.historic ? c.gold : c.textSecondary,
                size: 20),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mosque.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(mosque.district,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textTertiary)),
                if (_badges(c).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 8, children: _badges(c)),
                  ),
              ],
            ),
          ),
          Icon(AppIcons.forward, size: 16, color: c.textTertiary),
        ],
      ),
    );
  }

  List<Widget> _badges(SelayaColors c) {
    final b = <Widget>[];
    if (mosque.selatin) b.add(Icon(AppIcons.crown, size: 14, color: c.gold));
    if (mosque.disabledAccess) {
      b.add(Icon(Icons.accessible_rounded, size: 14, color: c.success));
    }
    if (mosque.womenArea) {
      b.add(Icon(Icons.woman_rounded, size: 14, color: c.accent));
    }
    if (mosque.quranCourse) {
      b.add(Icon(AppIcons.book, size: 14, color: c.textSecondary));
    }
    return b;
  }
}

class _ProvinceSheet extends StatefulWidget {
  final List<Province> provinces;
  final ValueChanged<Province> onSelected;
  const _ProvinceSheet({required this.provinces, required this.onSelected});
  @override
  State<_ProvinceSheet> createState() => _ProvinceSheetState();
}

class _ProvinceSheetState extends State<_ProvinceSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final list = _q.isEmpty
        ? widget.provinces
        : widget.provinces
            .where((p) => p.name.toLowerCase().contains(_q.toLowerCase()))
            .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'mosques.province'.tr(),
                prefixIcon: const Icon(AppIcons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: c.surfaceAlt,
                border: OutlineInputBorder(
                    borderRadius: AppRadius.rLg,
                    borderSide: BorderSide(color: c.border)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(list[i].name),
                trailing: Text('${list[i].count}',
                    style: TextStyle(color: c.textTertiary)),
                onTap: () {
                  widget.onSelected(list[i]);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MosqueDetailSheet extends StatelessWidget {
  final Mosque mosque;
  final String province;
  const _MosqueDetailSheet({required this.mosque, required this.province});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final features = <(bool, String, IconData)>[
      (mosque.historic, 'mosques.historic'.tr(), Icons.account_balance_rounded),
      (mosque.selatin, 'mosques.selatin'.tr(), AppIcons.crown),
      (mosque.disabledAccess, 'mosques.disabled'.tr(), Icons.accessible_rounded),
      (mosque.womenArea, 'mosques.women'.tr(), Icons.woman_rounded),
      (mosque.quranCourse, 'mosques.quranCourse'.tr(), AppIcons.book),
      (mosque.morningGathering, 'mosques.morning'.tr(), AppIcons.sunrise),
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.9,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(mosque.name, style: Theme.of(context).textTheme.headlineSmall),
          const Gap.xs(),
          Row(
            children: [
              Icon(AppIcons.location, size: 16, color: c.gold),
              const SizedBox(width: 4),
              Text('$province · ${mosque.district}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.textSecondary)),
            ],
          ),
          const Gap.md(),
          if (mosque.address.isNotEmpty)
            Text(mosque.address,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.textSecondary, height: 1.5)),
          const Gap.lg(),
          Text('mosques.features'.tr(),
              style: Theme.of(context).textTheme.titleSmall),
          const Gap.sm(),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(f.$3, size: 18, color: f.$1 ? c.gold : c.textTertiary),
                  const Gap.md(),
                  Expanded(child: Text(f.$2)),
                  Icon(
                      f.$1
                          ? AppIcons.checkCircle
                          : Icons.remove_circle_outline_rounded,
                      size: 18,
                      color: f.$1 ? c.success : c.textTertiary),
                ],
              ),
            ),
          const Gap.lg(),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openDirections(
                      query: '${mosque.name} ${mosque.district} $province camii'),
                  icon: const Icon(AppIcons.location, size: 18),
                  label: Text('mosques.directions'.tr()),
                  style: FilledButton.styleFrom(
                      backgroundColor: c.gold,
                      foregroundColor: c.onGold),
                ),
              ),
              const Gap.sm(),
              IconButton(
                onPressed: () => SharePlus.instance.share(ShareParams(
                    text:
                        '${mosque.name}\n${mosque.address}\n$province · ${mosque.district}\n\nSELAYA')),
                icon: Icon(AppIcons.share, color: c.textPrimary),
                style: IconButton.styleFrom(
                    side: BorderSide(color: c.border),
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
