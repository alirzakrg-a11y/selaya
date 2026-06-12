import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/like_button.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../data/audio_story_controller.dart';
import 'audio_story_now_playing.dart';

/// Records "catId:index" as the most recently played (deduped, capped at 8).
void addRecentAudio(SharedPreferences prefs, String catId, int index) {
  final key = '$catId:$index';
  final list = prefs.getStringList(PrefKeys.recentAudio) ?? <String>[];
  list.remove(key);
  list.insert(0, key);
  if (list.length > 8) list.removeRange(8, list.length);
  prefs.setStringList(PrefKeys.recentAudio, list);
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

class AudioStoriesScreen extends ConsumerWidget {
  const AudioStoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final async = ref.watch(audioStoriesProvider);

    return SelayaScaffold(
      title: 'audioStories.title'.tr(),
      showBack: true,
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (cats) {
          final recents = _resolveRecents(
              cats, ref.read(sharedPreferencesProvider));
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm,
                AppSpacing.base, AppSpacing.xxxl),
            children: [
              if (recents.isNotEmpty) ...[
                Text('audioStories.recent'.tr(),
                    style: Theme.of(context).textTheme.titleLarge),
                const Gap.sm(),
                SizedBox(
                  height: 158,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recents.length,
                    separatorBuilder: (_, _) => const Gap.sm(),
                    itemBuilder: (context, i) => _RecentCard(
                      category: recents[i].cat,
                      index: recents[i].index,
                      lang: lang,
                    ),
                  ),
                ),
                const Gap.lg(),
              ],
              for (final cat in cats) _CategoryBlock(category: cat, lang: lang),
            ],
          );
        },
      ),
    );
  }
}

/// Resolves the persisted "catId:index" recents to live (category, index) pairs.
List<({AudioStoryCategory cat, int index})> _resolveRecents(
    List<AudioStoryCategory> cats, SharedPreferences prefs) {
  final out = <({AudioStoryCategory cat, int index})>[];
  for (final r in prefs.getStringList(PrefKeys.recentAudio) ?? const []) {
    final parts = r.split(':');
    if (parts.length != 2) continue;
    final idx = int.tryParse(parts[1]);
    if (idx == null) continue;
    final matches = cats.where((c) => c.id == parts[0]);
    if (matches.isEmpty) continue;
    final cat = matches.first;
    if (idx < 0 || idx >= cat.episodes.length) continue;
    out.add((cat: cat, index: idx));
  }
  return out;
}

class _RecentCard extends ConsumerWidget {
  final AudioStoryCategory category;
  final int index;
  final String lang;
  const _RecentCard(
      {required this.category, required this.index, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ep = category.episodes[index];
    return GestureDetector(
      onTap: () {
        addRecentAudio(ref.read(sharedPreferencesProvider), category.id, index);
        ref
            .read(audioStoryControllerProvider.notifier)
            .play(category, index, lang);
        openAudioStoryNowPlaying(context);
      },
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadius.rLg,
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage.cdn(category.cover, fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x3305070D), Color(0xCC05070D)],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                        child: Icon(AppIcons.play,
                            color: category.accentColor, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap.xs(),
            Text(ep.title(lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _CategoryBlock extends ConsumerWidget {
  final AudioStoryCategory category;
  final String lang;
  const _CategoryBlock({required this.category, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.rXl,
          child: AspectRatio(
            aspectRatio: 16 / 7,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage.cdn(category.cover, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x3305070D), Color(0xE605070D)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(audioIconFor(category.iconKey),
                          color: category.accentColor, size: 24),
                      const Gap.xs(),
                      Text(category.title(lang),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white)),
                      Text(category.subtitle(lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap.sm(),
        for (var i = 0; i < category.episodes.length; i++)
          _EpisodeTile(
            episode: category.episodes[i],
            lang: lang,
            accent: c.gold,
            // ⑨ Beğeni: taban (id'ye göre rastgele görünümlü) + sunucu + kullanıcı;
            // beğeni POST'u sunucuya her zaman kaydolur (girişli/girişsiz).
            likeKey: 'story:${category.id}:$i',
            onTap: () {
              addRecentAudio(
                  ref.read(sharedPreferencesProvider), category.id, i);
              ref
                  .read(audioStoryControllerProvider.notifier)
                  .play(category, i, lang);
              openAudioStoryNowPlaying(context);
            },
          ),
        const Gap.lg(),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final AudioEpisode episode;
  final String lang;
  final Color accent;
  final VoidCallback onTap;
  final String? likeKey;
  const _EpisodeTile({
    required this.episode,
    required this.lang,
    required this.accent,
    required this.onTap,
    this.likeKey,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rLg,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle),
              child: Icon(AppIcons.play, color: accent, size: 20),
            ),
            const Gap.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(episode.title(lang),
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(episode.subtitle(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textTertiary)),
                ],
              ),
            ),
            if (episode.durationSec > 0)
              Text(formatDuration(episode.durationSec),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textTertiary)),
            if (likeKey != null) ...[
              const Gap.xs(),
              LikeButton(likeKey: likeKey!),
            ],
          ],
        ),
      ),
    );
  }
}
