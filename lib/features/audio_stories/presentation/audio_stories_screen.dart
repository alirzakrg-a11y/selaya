import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';

// ─── Ortak yardımcılar (player ekranı da kullanır) ───────────────────────────

/// "catId:index"i en son dinlenen olarak kaydeder (tekilleştirir, 8 ile sınırlar).
void addRecentAudio(SharedPreferences prefs, String catId, int index) {
  final key = '$catId:$index';
  final list = prefs.getStringList(PrefKeys.recentAudio) ?? <String>[];
  list.remove(key);
  list.insert(0, key);
  if (list.length > 8) list.removeRange(8, list.length);
  prefs.setStringList(PrefKeys.recentAudio, list);
}

bool isFavoriteAudio(SharedPreferences prefs, String catId, int index) =>
    (prefs.getStringList(PrefKeys.favoriteAudio) ?? const <String>[])
        .contains('$catId:$index');

void toggleFavoriteAudio(SharedPreferences prefs, String catId, int index) {
  final key = '$catId:$index';
  final list = prefs.getStringList(PrefKeys.favoriteAudio) ?? <String>[];
  list.contains(key) ? list.remove(key) : list.insert(0, key);
  prefs.setStringList(PrefKeys.favoriteAudio, list);
}

IconData audioIconFor(String key) => switch (key) {
      'prophets' => AppIcons.prophets,
      'moon' => AppIcons.moon,
      'sparkles' => AppIcons.sparkles,
      'knowledge' => AppIcons.knowledge,
      'dua' => AppIcons.dua,
      'prayerRug' => AppIcons.prayerRug,
      'mosque' => AppIcons.mosque,
      _ => AppIcons.headphones,
    };

String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

typedef _Track = ({AudioStoryCategory cat, int index, AudioEpisode ep});

/// Kalıcı "catId:index" listesini canlı (kategori, index) çiftlerine çözer.
List<_Track> _resolveRecents(
    List<AudioStoryCategory> cats, SharedPreferences prefs) {
  final out = <_Track>[];
  for (final r in prefs.getStringList(PrefKeys.recentAudio) ?? const []) {
    final parts = r.split(':');
    if (parts.length != 2) continue;
    final idx = int.tryParse(parts[1]);
    if (idx == null) continue;
    final matches = cats.where((c) => c.id == parts[0]);
    if (matches.isEmpty) continue;
    final cat = matches.first;
    if (idx < 0 || idx >= cat.episodes.length) continue;
    out.add((cat: cat, index: idx, ep: cat.episodes[idx]));
  }
  return out;
}

// ─── Liste ekranı (mockup) ───────────────────────────────────────────────────

class AudioStoriesScreen extends ConsumerStatefulWidget {
  const AudioStoriesScreen({super.key});

  @override
  ConsumerState<AudioStoriesScreen> createState() => _AudioStoriesScreenState();
}

class _AudioStoriesScreenState extends ConsumerState<AudioStoriesScreen> {
  String _query = '';
  String? _selectedCat; // null = tümü

  void _openPlayer(String catId, int index) =>
      context.push('${Routes.audioStories}/player/$catId/$index');

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final async = ref.watch(audioStoriesProvider);
    return SelayaScaffold(
      showBack: true,
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (cats) {
          if (cats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.headphones,
                        size: 48, color: context.colors.textTertiary),
                    const Gap.md(),
                    Text('audioStories.empty'.tr(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            );
          }
          final prefs = ref.read(sharedPreferencesProvider);
          final recents = _resolveRecents(cats, prefs);
          final all = <_Track>[
            for (final cat in cats)
              for (var i = 0; i < cat.episodes.length; i++)
                (cat: cat, index: i, ep: cat.episodes[i]),
          ];
          final q = _query.trim().toLowerCase();
          final filtered = all.where((t) {
            if (_selectedCat != null && t.cat.id != _selectedCat) return false;
            if (q.isEmpty) return true;
            return t.ep.title(lang).toLowerCase().contains(q) ||
                t.cat.title(lang).toLowerCase().contains(q);
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, 0, AppSpacing.base, AppSpacing.xxxl),
            children: [
              _Hero(lang: lang, prefs: prefs),
              const Gap.lg(),
              _SearchField(onChanged: (v) => setState(() => _query = v)),
              const Gap.lg(),
              _SectionHeader(title: 'audioStories.categories'.tr()),
              const Gap.sm(),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CategoryChip(
                      label: 'audioStories.all'.tr(),
                      icon: AppIcons.sparkles,
                      selected: _selectedCat == null,
                      color: context.colors.gold,
                      onTap: () => setState(() => _selectedCat = null),
                    ),
                    for (final cat in cats)
                      _CategoryChip(
                        label: cat.title(lang),
                        icon: audioIconFor(cat.iconKey),
                        selected: _selectedCat == cat.id,
                        color: cat.accentColor,
                        onTap: () => setState(() => _selectedCat =
                            _selectedCat == cat.id ? null : cat.id),
                      ),
                  ],
                ),
              ),
              if (recents.isNotEmpty && _query.isEmpty) ...[
                const Gap.lg(),
                _SectionHeader(title: 'audioStories.recent'.tr()),
                const Gap.sm(),
                _ContinueCard(
                  track: recents.first,
                  lang: lang,
                  onTap: () =>
                      _openPlayer(recents.first.cat.id, recents.first.index),
                ),
              ],
              const Gap.lg(),
              _SectionHeader(title: 'audioStories.popular'.tr()),
              const Gap.sm(),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Text('audioStories.empty'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: context.colors.textTertiary)),
                  ),
                )
              else
                for (var i = 0; i < filtered.length; i++)
                  _PopularTile(
                    number: i + 1,
                    track: filtered[i],
                    lang: lang,
                    favorite:
                        isFavoriteAudio(prefs, filtered[i].cat.id, filtered[i].index),
                    onTap: () =>
                        _openPlayer(filtered[i].cat.id, filtered[i].index),
                    onFav: () {
                      toggleFavoriteAudio(
                          prefs, filtered[i].cat.id, filtered[i].index);
                      setState(() {});
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String lang;
  final SharedPreferences prefs;
  const _Hero({required this.lang, required this.prefs});

  String _name() {
    final raw = prefs.getString(PrefKeys.authUser);
    if (raw == null || raw.isEmpty) return '';
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return (m['name'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = _name();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.rXl,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.gold.withValues(alpha: 0.22), c.surfaceAlt],
        ),
        border: Border.all(color: c.gold.withValues(alpha: 0.25)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            top: -6,
            child: Icon(AppIcons.headphones,
                size: 64, color: c.gold.withValues(alpha: 0.18)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty) ...[
                Text('audioStories.welcome'.tr(args: [name]),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.textSecondary)),
                const Gap.xs(),
              ],
              Text('audioStories.heroTitle'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Gap.xs(),
              Padding(
                padding: const EdgeInsets.only(right: 48),
                child: Text('audioStories.heroSubtitle'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.textSecondary, height: 1.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: 'audioStories.search'.tr(),
        prefixIcon: Icon(Icons.search_rounded, color: c.textTertiary, size: 20),
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
            borderRadius: AppRadius.rLg, borderSide: BorderSide.none),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Text(title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700));
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? color.withValues(alpha: 0.16) : c.surfaceAlt,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                  color: selected ? color : c.border, width: selected ? 1.3 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: selected ? color : c.textSecondary),
              const Gap.xs(),
              Text(label,
                  style: TextStyle(
                      color: selected ? color : c.textSecondary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final _Track track;
  final String lang;
  final VoidCallback onTap;
  const _ContinueCard(
      {required this.track, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cover =
        track.ep.cover.isNotEmpty ? track.ep.cover : track.cat.cover;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rLg,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
            color: c.surfaceAlt, borderRadius: AppRadius.rLg),
        child: Row(children: [
          ClipRRect(
            borderRadius: AppRadius.rMd,
            child: SizedBox(
                width: 56,
                height: 56,
                child: AppImage.cdn(cover, fit: BoxFit.cover)),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.ep.title(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                const Gap.xs(),
                Row(children: [
                  Icon(AppIcons.play, size: 13, color: c.gold),
                  const Gap.xs(),
                  Text('audioStories.continueLabel'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.gold, fontWeight: FontWeight.w600)),
                  if (track.ep.durationSec > 0) ...[
                    Text('  ·  ',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: c.textTertiary)),
                    Text(formatDuration(track.ep.durationSec),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: c.textTertiary)),
                  ],
                ]),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: c.gold, shape: BoxShape.circle),
            padding: const EdgeInsets.all(8),
            child:
                const Icon(Icons.play_arrow_rounded, color: Color(0xFF1A1203)),
          ),
        ]),
      ),
    );
  }
}

class _PopularTile extends StatelessWidget {
  final int number;
  final _Track track;
  final String lang;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFav;
  const _PopularTile(
      {required this.number,
      required this.track,
      required this.lang,
      required this.favorite,
      required this.onTap,
      required this.onFav});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cover =
        track.ep.cover.isNotEmpty ? track.ep.cover : track.cat.cover;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rLg,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(children: [
          ClipRRect(
            borderRadius: AppRadius.rMd,
            child: SizedBox(
                width: 48,
                height: 48,
                child: AppImage.cdn(cover, fit: BoxFit.cover)),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$number. ${track.ep.title(lang)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                if (track.ep.durationSec > 0) ...[
                  const Gap.xs(),
                  Text(formatDuration(track.ep.durationSec),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textTertiary)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
                favorite
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: favorite ? c.gold : c.textTertiary,
                size: 20),
            onPressed: onFav,
          ),
        ]),
      ),
    );
  }
}
