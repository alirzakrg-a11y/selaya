import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/share/share_helper.dart';
import '../../../core/models/content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/states.dart';
import '../../audio_stories/data/audio_handler.dart';

/// Route wrapper: loads stories then shows the immersive player.
class StoryViewerScreen extends ConsumerWidget {
  final int startIndex;
  const StoryViewerScreen({super.key, required this.startIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(storiesProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: stories.when(
        data: (list) => list.isEmpty
            ? const SelayaEmpty()
            : StoryPlayer(stories: list, startIndex: startIndex.clamp(0, list.length - 1)),
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
      ),
    );
  }
}

class StoryPlayer extends ConsumerStatefulWidget {
  final List<Story> stories;
  final int startIndex;
  const StoryPlayer({super.key, required this.stories, required this.startIndex});

  @override
  ConsumerState<StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends ConsumerState<StoryPlayer>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progress;
  late int _story;
  int _slide = 0;
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _story = widget.startIndex;
    _pageController = PageController(initialPage: _story);
    _progress = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _nextSlide();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSlide());
  }

  @override
  void dispose() {
    _disposeVideo();
    _progress.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Story get _current => widget.stories[_story];

  void _disposeVideo() {
    _video?.dispose();
    _video = null;
  }

  void _startSlide() {
    _disposeVideo();
    final slide = _current.slides[_slide];
    final vid = slide.video;
    if (vid != null && vid.isNotEmpty) {
      _startVideoSlide(vid);
    } else {
      _progress.stop();
      _progress.duration = Duration(milliseconds: slide.durationMs);
      _progress.forward(from: 0);
    }
  }

  /// Video hikâye bölümü: oynat + ilerleme çubuğunu video süresine ayarla.
  void _startVideoSlide(String url) {
    _progress.stop();
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = ctrl;
    ctrl.initialize().then((_) {
      if (!mounted || _video != ctrl) return;
      ctrl
        ..setLooping(false)
        ..play();
      // Video hikâye SESLİ çalar → arka plandaki Kur'an/Yâsîn'i duraklat (çift
      // ses olmasın; akış videosundaki ile aynı kural).
      ref.read(audioHandlerProvider).pause();
      _progress.duration = ctrl.value.duration > Duration.zero
          ? ctrl.value.duration
          : const Duration(seconds: 15);
      _progress.forward(from: 0);
      setState(() {});
    }).catchError((_) {
      if (!mounted) return;
      _progress.duration = const Duration(seconds: 8);
      _progress.forward(from: 0);
    });
  }

  void _nextSlide() {
    if (_slide < _current.slides.length - 1) {
      setState(() => _slide++);
      _startSlide();
    } else {
      _nextStory();
    }
  }

  void _prevSlide() {
    if (_slide > 0) {
      setState(() => _slide--);
      _startSlide();
    } else {
      _prevStory();
    }
  }

  void _nextStory() {
    if (_story < widget.stories.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prevStory() {
    if (_story > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.stories.length,
      onPageChanged: (i) {
        setState(() {
          _story = i;
          _slide = 0;
        });
        _startSlide();
      },
      itemBuilder: (context, i) {
        final story = widget.stories[i];
        final slide = story.slides[i == _story ? _slide : 0];
        return GestureDetector(
          onTapUp: (d) {
            final w = MediaQuery.sizeOf(context).width;
            d.globalPosition.dx < w * 0.35 ? _prevSlide() : _nextSlide();
          },
          onLongPressStart: (_) {
            _progress.stop();
            _video?.pause();
          },
          onLongPressEnd: (_) {
            _progress.forward();
            _video?.play();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              (i == _story &&
                      slide.video != null &&
                      slide.video!.isNotEmpty &&
                      _video != null &&
                      _video!.value.isInitialized)
                  ? FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _video!.value.size.width,
                        height: _video!.value.size.height,
                        child: VideoPlayer(_video!),
                      ),
                    )
                  : AppImage.cdn(slide.image,
                      fit: BoxFit.cover,
                      fallbackColors: [
                        story.accentColor.withValues(alpha: 0.6),
                        Colors.black
                      ]),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent, Colors.black87],
                    stops: [0, 0.4, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProgressBars(
                        count: story.slides.length,
                        current: i == _story ? _slide : 0,
                        controller: _progress,
                        active: i == _story,
                      ),
                      const Gap.md(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                  colors: [story.accentColor, AppColors.goldBright]),
                            ),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.black,
                              child: ClipOval(
                                child: AppImage.cdn(story.cover,
                                    width: 36, height: 36, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                          const Gap.sm(),
                          Expanded(
                            child: Text(story.title(lang),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                          IconButton(
                            icon: const Icon(AppIcons.share, color: Colors.white),
                            onPressed: () {
                              _progress.stop();
                              showVerseShareSheet(
                                context,
                                arabic: slide.arabic,
                                text: slide.body(lang),
                                reference: slide.heading(lang).isEmpty
                                    ? story.title(lang)
                                    : slide.heading(lang),
                                label: story.title(lang),
                                backgroundImage: slide.image,
                              ).then((_) {
                                if (mounted) _progress.forward();
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(AppIcons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (slide.arabic != null) ...[
                        Text(
                          slide.arabic!,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: AppTypography.arabic(
                              fontSize: 30, color: Colors.white),
                        ),
                        const Gap.lg(),
                      ],
                      if (slide.heading(lang).isNotEmpty)
                        Text(slide.heading(lang),
                            style: const TextStyle(
                                color: AppColors.goldBright,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      const Gap.xs(),
                      Text(
                        slide.body(lang),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, height: 1.45),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressBars extends StatelessWidget {
  final int count;
  final int current;
  final AnimationController controller;
  final bool active;
  const _ProgressBars({
    required this.count,
    required this.current,
    required this.controller,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < count; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (_, _) {
                    double v;
                    if (i < current) {
                      v = 1;
                    } else if (i == current && active) {
                      v = controller.value;
                    } else {
                      v = 0;
                    }
                    return LinearProgressIndicator(
                      value: v,
                      minHeight: 2.5,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
