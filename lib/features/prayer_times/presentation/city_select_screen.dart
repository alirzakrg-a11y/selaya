import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/permissions_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/permission_dialog.dart';
import '../../../core/widgets/states.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/prayer_repository.dart';
import '../domain/prayer.dart';

class CitySelectScreen extends ConsumerStatefulWidget {
  const CitySelectScreen({super.key});
  @override
  ConsumerState<CitySelectScreen> createState() => _CitySelectScreenState();
}

class _CitySelectScreenState extends ConsumerState<CitySelectScreen> {
  final _searchCtrl = TextEditingController();
  String _q = '';
  bool _locating = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    final result = await ref
        .read(permissionsControllerProvider.notifier)
        .useDeviceLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    switch (result) {
      case LocationFlowResult.needsSettings:
        await showOpenSettingsDialog(
            context, ref.read(permissionServiceProvider),
            title: 'settings.locationPermTitle'.tr(),
            message: 'settings.locationPermBody'.tr());
      case LocationFlowResult.noFix:
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('settings.locationFailed'.tr())));
      case LocationFlowResult.denied:
        break;
      case LocationFlowResult.saved:
        Navigator.of(context).maybePop();
    }
  }

  void _selectCity(String id) {
    ref.read(settingsProvider.notifier).setCity(id);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final cities = ref.watch(citiesProvider);
    final selectedId = ref.watch(settingsProvider.select((s) => s.cityId));

    return SelayaScaffold(
      title: 'prayer.selectCity'.tr(),
      showBack: true,
      body: cities.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (all) {
          final q = _q.trim().toLowerCase();
          final list = q.isEmpty
              ? all
              : all
                  .where((city) =>
                      city.name(lang).toLowerCase().contains(q) ||
                      city.countryName(lang).toLowerCase().contains(q))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                child: _LocationHero(
                  locating: _locating,
                  onTap: _locating ? null : _useLocation,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                child: _SearchField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _q = v),
                  onClear: () => setState(() {
                    _searchCtrl.clear();
                    _q = '';
                  }),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? SelayaEmpty(
                        icon: AppIcons.search,
                        message: 'common.empty'.tr(),
                      )
                    : _CityList(
                        cities: list,
                        lang: lang,
                        selectedId: selectedId,
                        onSelect: _selectCity,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Gradient "use my location" hero — replaces the old flat button.
class _LocationHero extends StatelessWidget {
  final bool locating;
  final VoidCallback? onTap;
  const _LocationHero({required this.locating, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rLg,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          borderRadius: AppRadius.rLg,
          gradient: LinearGradient(
            colors: [c.gold.withValues(alpha: 0.22), c.surfaceAlt],
          ),
          border: Border.all(color: c.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.gold.withValues(alpha: 0.18)),
              child: locating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold))
                  : Icon(AppIcons.location, color: c.gold, size: 22),
            ),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      locating
                          ? 'settings.locating'.tr()
                          : 'settings.useLocation'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('prayer.useLocationDesc'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            if (!locating)
              Icon(AppIcons.forward, size: 16, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'common.search'.tr(),
        prefixIcon: const Icon(AppIcons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(AppIcons.close, size: 18),
                onPressed: onClear,
              ),
        filled: true,
        fillColor: c.surfaceAlt,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
    );
  }
}

/// Cities grouped by country with section headers + a highlighted selection.
class _CityList extends StatelessWidget {
  final List<City> cities;
  final String lang;
  final String selectedId;
  final ValueChanged<String> onSelect;
  const _CityList({
    required this.cities,
    required this.lang,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Build a flat list of header/city rows preserving the input order.
    final rows = <Widget>[];
    String? country;
    for (final city in cities) {
      if (city.country != country) {
        country = city.country;
        rows.add(Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.xs,
              rows.isEmpty ? 0 : AppSpacing.md, AppSpacing.xs, AppSpacing.xs),
          child: Text(city.countryName(lang).toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.gold,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700)),
        ));
      }
      final selected = city.id == selectedId;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InkWell(
          onTap: () => onSelect(city.id),
          borderRadius: AppRadius.rLg,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: selected ? c.gold.withValues(alpha: 0.12) : c.surfaceAlt,
              borderRadius: AppRadius.rLg,
              border: Border.all(
                  color: selected ? c.gold : c.border,
                  width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(AppIcons.location,
                    color: selected ? c.gold : c.textTertiary, size: 20),
                const Gap.md(),
                Expanded(
                  child: Text(city.name(lang),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600)),
                ),
                if (selected) Icon(AppIcons.checkCircle, color: c.gold, size: 20),
              ],
            ),
          ),
        ),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.xs, AppSpacing.base, AppSpacing.xxxl),
      children: rows,
    );
  }
}
