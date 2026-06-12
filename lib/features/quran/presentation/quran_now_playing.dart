import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/instant_swipe.dart';
import '../../../core/widgets/mini_player_chrome.dart';
import '../data/quran_audio_controller.dart';
import '../data/quran_favorites.dart';
import '../data/quran_tracks.dart';

/// Kuran/Yâsîn "şimdi çalıyor" ekranı — sesli hikâyelerdeki gibi slide-up:
/// kapak (günlük duvar kâğıdı) + transport + sıradaki ayetler (kuyruk) + durdur.
class QuranNowPlaying extends ConsumerWidget {
  const QuranNowPlaying({super.key});

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lang = context.langCode;
    final allSurahs = ref.watch(surahsProvider).value ?? const <Surah>[];
    final st = ref.watch(quranAudioControllerProvider);
    final favs = ref.watch(quranFavoritesProvider);
    final ctrl = ref.read(quranAudioControllerProvider.notifier);
    final tracks = ctrl.tracks;
    if (st.surahNumber == null || tracks.isEmpty) {
      return Scaffold(
          backgroundColor: c.bg, body: const Center(child: Text('—')));
    }
    final art = ctrl.art;

    return Scaffold(
      backgroundColor: c.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.7),
            radius: 1.1,
            colors: [c.goldDeep.withValues(alpha: 0.3), c.bg, c.bg],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // ② Aşağı kaydır → kapat; ANINDA tepki (tutamak; aşağı-ok da var).
                InstantSwipe(
                  onDown: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.textTertiary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 30),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    // ⑦ Favori yıldızı — bu sureyi favorile (Kur'an "Favoriler"le
                    // aynı anahtar → liste ile tutarlı).
                    IconButton(
                      icon: Icon(favs.contains(st.surahNumber)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded),
                      color: favs.contains(st.surahNumber)
                          ? c.danger
                          : c.textSecondary,
                      onPressed: () => ref
                          .read(quranFavoritesProvider.notifier)
                          .toggle(st.surahNumber!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop_circle_outlined),
                      color: c.textSecondary,
                      onPressed: () {
                        ctrl.stop();
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ],
                ),
                StreamBuilder<int?>(
                  stream: ctrl.currentIndexStream,
                  builder: (context, snap) {
                    final i = (snap.data ?? ctrl.currentIndex)
                        .clamp(0, tracks.length - 1);
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: art.isNotEmpty
                              ? AppImage.cdn(art,
                                  width: 200, height: 200, fit: BoxFit.cover)
                              : Container(
                                  width: 200,
                                  height: 200,
                                  color: c.surfaceAlt,
                                  child: Icon(Icons.menu_book_rounded,
                                      size: 64, color: c.gold)),
                        ),
                        const Gap.md(),
                        Text(st.surahName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(tracks[i].title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: c.gold)),
                      ],
                    );
                  },
                ),
                const Gap.sm(),
                _QSeekBar(ctrl: ctrl),
                const Gap.xs(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 38,
                      color: c.textSecondary,
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: ctrl.previous,
                    ),
                    const Gap.md(),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            LinearGradient(colors: [c.goldBright, c.goldDeep]),
                      ),
                      child: IconButton(
                        iconSize: 50,
                        color: c.bg,
                        icon: Icon(st.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                        onPressed: ctrl.toggle,
                      ),
                    ),
                    const Gap.md(),
                    IconButton(
                      iconSize: 38,
                      color: c.textSecondary,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: ctrl.next,
                    ),
                  ],
                ),
                const Gap.md(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('quran.queue'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: c.textSecondary)),
                      ),
                      const Gap.xs(),
                      StreamBuilder<int?>(
                        stream: ctrl.currentIndexStream,
                        builder: (context, snap) {
                          final cur = (snap.data ?? ctrl.currentIndex)
                              .clamp(0, tracks.length - 1);
                          return Column(
                            children: [
                              for (var i = 0; i < tracks.length; i++)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () => ctrl.jumpTo(i),
                                  leading: Icon(
                                      i == cur
                                          ? Icons.graphic_eq_rounded
                                          : Icons.play_circle_outline_rounded,
                                      color: c.gold),
                                  title: Text(tracks[i].title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: i == cur
                                              ? c.gold
                                              : c.textPrimary,
                                          fontWeight: i == cur
                                              ? FontWeight.w700
                                              : FontWeight.w500)),
                                ),
                            ],
                          );
                        },
                      ),
                      // ③ Tüm Kur'an sureleri — listede gör + dokun → o sureye geç.
                      if (allSurahs.isNotEmpty) ...[
                        const Gap.lg(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                              lang == 'tr' ? 'Tüm Sureler' : 'All Surahs',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: c.textSecondary)),
                        ),
                        const Gap.xs(),
                        for (final s in allSurahs)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onTap: () async {
                              final verses = await ref
                                  .read(versesProvider(s.number).future);
                              final surahTracks = buildQuranTracks(
                                  s.number,
                                  s.name(lang),
                                  verses,
                                  quranWallpaperArt(ref, s.number));
                              if (surahTracks.isNotEmpty) {
                                await ctrl.play(
                                    s.number, s.name(lang), surahTracks, 0);
                              }
                            },
                            leading: CircleAvatar(
                              radius: 13,
                              backgroundColor: s.number == st.surahNumber
                                  ? c.gold
                                  : c.gold.withValues(alpha: 0.14),
                              child: Text('${s.number}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: s.number == st.surahNumber
                                          ? c.bg
                                          : c.gold)),
                            ),
                            title: Text(s.name(lang),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: s.number == st.surahNumber
                                        ? c.gold
                                        : c.textPrimary,
                                    fontWeight: s.number == st.surahNumber
                                        ? FontWeight.w700
                                        : FontWeight.w500)),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QSeekBar extends StatelessWidget {
  final QuranAudioController ctrl;
  const _QSeekBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StreamBuilder<Duration?>(
      stream: ctrl.durationStream,
      builder: (context, durSnap) {
        final total = durSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: ctrl.positionStream,
          builder: (context, posSnap) {
            var pos = posSnap.data ?? Duration.zero;
            if (pos > total) pos = total;
            final maxMs = total.inMilliseconds.toDouble();
            final value = maxMs <= 0
                ? 0.0
                : pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: c.gold,
                    inactiveTrackColor: c.border,
                    thumbColor: c.gold,
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs <= 0 ? 1 : maxMs,
                    value: value,
                    onChanged: (v) =>
                        ctrl.seek(Duration(milliseconds: v.round())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(QuranNowPlaying._fmt(pos),
                          style:
                              TextStyle(color: c.textTertiary, fontSize: 11)),
                      Text(QuranNowPlaying._fmt(total),
                          style:
                              TextStyle(color: c.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Slide-up açılış (alttan yukarı kayan now-playing ekranı). Global mini'den
/// de çağrılır (Navigator ağacının DIŞINDA yaşar) → root key ile push edilir.
/// Açıkken global mini gizlenir; nasıl kapanırsa kapansın (aşağı kaydır, geri,
/// durdur) `.then` ile geri görünür.
void openQuranNowPlaying(BuildContext context) {
  final nav = rootNavigatorKey.currentState ?? Navigator.of(context);
  fullScreenPlayerOpen.value = true;
  nav
      .push(PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => const QuranNowPlaying(),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ))
      .then((_) => fullScreenPlayerOpen.value = false);
}
