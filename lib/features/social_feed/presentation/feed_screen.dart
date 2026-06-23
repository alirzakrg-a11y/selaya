import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/data/likes_service.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/services/gallery_service.dart';
import '../../../core/services/share_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/states.dart';

/// Reels-style vertical video feed. The page in view autoplays; when a clip
/// finishes it advances to the next on its own, and the last clip loops back to
/// the first — so the feed feels endless. Swiping up/down still works manually.
/// Video sources are local assets today and can be swapped to remote URLs later
/// without touching the UI — see [_FeedPageState._initVideo].
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _current = widget.initialIndex;
  bool _muted = false; // global: bir klipte sessize alınca hepsi sessiz kalır

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Called when the active clip finishes: glide to the next one, or wrap from
  /// the last back to the first so playback never stops.
  void _advance(int length) {
    if (length <= 1) return;
    final next = (_current + 1) % length;
    if (next > _current) {
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(next); // last → first
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: feed.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (items) {
          if (items.isEmpty) return const SizedBox.shrink();
          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: items.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) => _FeedPage(
                  item: items[i],
                  active: i == _current,
                  muted: _muted,
                  onToggleMute: () => setState(() => _muted = !_muted),
                  onCompleted: () => _advance(items.length),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(AppIcons.back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeedPage extends ConsumerStatefulWidget {
  final FeedItem item;
  final bool active;
  final bool muted;
  final VoidCallback onCompleted;
  final VoidCallback onToggleMute;
  const _FeedPage({
    required this.item,
    required this.active,
    required this.muted,
    required this.onCompleted,
    required this.onToggleMute,
  });

  @override
  ConsumerState<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<_FeedPage> {
  VideoPlayerController? _video;
  bool _ready = false;
  bool _paused = false;
  bool _ended = false;

  bool get _hasVideo => widget.item.video.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasVideo) _initVideo();
  }

  /// Local asset today, a remote URL later — [VideoPlayerController] handles
  /// both, so swapping the source string is the only change needed.
  Future<void> _initVideo() async {
    final src = widget.item.video;
    final controller = src.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(src))
        : VideoPlayerController.asset(src);
    _video = controller;
    try {
      await controller.initialize();
      // Play once, then let the feed advance to the next clip (no per-clip loop).
      await controller.setLooping(false);
      controller.setVolume(widget.muted ? 0 : 1);
      controller.addListener(_onValue);
      if (!mounted) return;
      setState(() => _ready = true);
      if (widget.active) controller.play();
    } catch (_) {
      // Keep the poster showing if the clip fails to load.
    }
  }

  /// Detects the end of the active clip and tells the feed to advance — fired
  /// once per playthrough via [_ended].
  void _onValue() {
    final c = _video;
    if (c == null || _ended || !widget.active) return;
    final v = c.value;
    if (v.isInitialized &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 80)) {
      _ended = true;
      widget.onCompleted();
    }
  }

  @override
  void didUpdateWidget(covariant _FeedPage old) {
    super.didUpdateWidget(old);
    final c = _video;
    if (c == null || !_ready) return;
    if (widget.muted != old.muted) c.setVolume(widget.muted ? 0 : 1);
    // Autoplay the clip that just scrolled into view; pause the one leaving.
    if (widget.active && !old.active) {
      _ended = false;
      _paused = false;
      c
        ..seekTo(Duration.zero)
        ..play();
    } else if (!widget.active && old.active) {
      c.pause();
    }
  }

  @override
  void dispose() {
    _video?.removeListener(_onValue);
    _video?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _video;
    if (c == null || !_ready) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        _paused = true;
      } else {
        c.play();
        _paused = false;
      }
    });
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    // Global sessiz: parent setState → didUpdateWidget tüm kliplere uygular.
    widget.onToggleMute();
  }

  /// Shares the actual video file so any app (WhatsApp, Instagram, Telegram…)
  /// receives it as a video, not just a link.
  Future<void> _share() async {
    final lang = context.langCode;
    final caption = widget.item.caption(lang);
    // Pause (and thus halt auto-advance) while the share sheet is open, then
    // resume once it closes — share_plus awaits the sheet's dismissal.
    final wasPlaying = _video?.value.isPlaying ?? false;
    _video?.pause();
    if (mounted) setState(() => _paused = true);
    const appName = 'SELAYA';
    final shareText = caption.trim().isEmpty
        ? '$appName · selaya.app'
        : '$caption\n\n$appName · selaya.app';
    await ref
        .read(shareServiceProvider)
        .shareVideo(
          widget.item.video,
          text: shareText,
          subject: appName,
          fileName: caption,
        );
    if (!mounted) return;
    if (wasPlaying && widget.active) {
      _video?.play();
      setState(() => _paused = false);
    }
  }

  /// Videoyu galeriye indir.
  Future<void> _download() async {
    final ok = await ref
        .read(galleryServiceProvider)
        .saveVideo(widget.item.video);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'wallpapers.saved'.tr() : 'wallpapers.saveError'.tr(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = _video;
    final likeKey = 'feed:${item.id}';
    final liked = ref.watch(likedKeysProvider).contains(likeKey);
    // TÜM beğeni yüzeyleriyle AYNI formül (LikeButton ile birebir): deterministik
    // taban (id'ye göre — her kullanıcıda aynı "rastgele" sayı) + API gerçek
    // beğenileri + yerel beğeni → anasayfa kartı ile oynatıcı EŞİT gösterir.
    final server = ref.watch(likesProvider).asData?.value[likeKey] ?? 0;
    final likeCount = likeSeed(likeKey) + server + (liked ? 1 : 0);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Tapping the video toggles play/pause. It sits at the BOTTOM of the
        // stack so the action buttons layered above intercept their own taps
        // first — otherwise a single parent gesture would also fire (and pause
        // the clip) every time the like/sound/share buttons are tapped.
        Positioned.fill(
          child: GestureDetector(
            onTap: _togglePlay,
            behavior: HitTestBehavior.opaque,
            child: (_ready && c != null)
                ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: c.value.size.width,
                      height: c.value.size.height,
                      child: VideoPlayer(c),
                    ),
                  )
                : AppImage.cdn(item.poster),
          ),
        ),
        // Decorative overlays — non-interactive, so taps fall through to the
        // video layer below.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Colors.transparent,
                  Color(0xDD000000),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
        ),
        if (_paused || !_hasVideo)
          IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: const Icon(AppIcons.play, color: Colors.white, size: 36),
              ),
            ),
          ),
        // Right action column: like, sound, share.
        Positioned(
          right: AppSpacing.base,
          bottom: 120,
          child: Column(
            children: [
              _FeedAction(
                icon: liked ? AppIcons.favoriteFilled : AppIcons.favorite,
                label: '$likeCount',
                color: liked ? AppColors.danger : Colors.white,
                // Çift yönlü: tekrar dokununca beğeniyi geri al (panelde −1).
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(likedKeysProvider.notifier).toggle(likeKey);
                },
              ),
              const Gap.lg(),
              if (_hasVideo) ...[
                _FeedAction(
                  icon: widget.muted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  label: widget.muted ? 'feed.muted'.tr() : 'feed.sound'.tr(),
                  color: Colors.white,
                  onTap: _toggleMute,
                ),
                const Gap.lg(),
              ],
              _FeedAction(
                icon: AppIcons.share,
                label: 'common.share'.tr(),
                color: Colors.white,
                onTap: _share,
              ),
              if (_hasVideo) ...[
                const Gap.lg(),
                _FeedAction(
                  icon: AppIcons.download,
                  label: 'common.download'.tr(),
                  color: Colors.white,
                  onTap: _download,
                ),
              ],
            ],
          ),
        ),
        // Caption: app name (branding) + line.
        Positioned(
          left: AppSpacing.base,
          right: 80,
          bottom: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black,
                    backgroundImage: AssetImage('assets/icon/selaya_icon.png'),
                  ),
                  const Gap.sm(),
                  const Text(
                    'SELAYA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const Gap.sm(),
              Text(
                item.caption(context.langCode),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
            ],
          ),
        ),
        // Video yüklenirken küçük spinner (poster üstünde).
        if (_hasVideo && !_ready)
          const IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white70),
              ),
            ),
          ),
        // İlerleme çubuğu (en altta).
        if (_ready && c != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (_, value, _) {
                  final dur = value.duration.inMilliseconds;
                  final p = dur > 0
                      ? (value.position.inMilliseconds / dur).clamp(0.0, 1.0)
                      : 0.0;
                  return LinearProgressIndicator(
                    value: p,
                    minHeight: 2.5,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFFE0B250)),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _FeedAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _FeedAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
