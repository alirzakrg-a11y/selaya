import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/data/likes_service.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/services/gallery_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/like_button.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';

class WallpapersScreen extends ConsumerWidget {
  const WallpapersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpapers = ref.watch(wallpapersProvider);

    return SelayaScaffold(
      title: 'wallpapers.title'.tr(),
      showBack: true,
      body: wallpapers.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (list) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.62,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) => _WallpaperTile(list: list, index: i),
        ),
      ),
    );
  }
}

class _WallpaperTile extends ConsumerWidget {
  final List<Wallpaper> list;
  final int index;
  const _WallpaperTile({required this.list, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final wp = list[index];
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => WallpaperDetail(list: list, index: index))),
      child: ClipRRect(
        borderRadius: AppRadius.rLg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Izgara: küçük önizleme + sınırlı decode → 1000 görselde de akıcı.
            AppImage.cdn(wp.gridImage,
                fallbackColors: wp.colors, memWidth: 560),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC05070D)],
                ),
              ),
            ),
            if (wp.premium)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(AppIcons.crown, color: AppColors.goldBright, size: 18),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(wp.title(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  LikeButton(likeKey: 'wallpaper:${wp.id}', light: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WallpaperDetail extends ConsumerStatefulWidget {
  final List<Wallpaper> list;
  final int index;
  const WallpaperDetail({super.key, required this.list, required this.index});

  @override
  ConsumerState<WallpaperDetail> createState() => _WallpaperDetailState();
}

class _WallpaperDetailState extends ConsumerState<WallpaperDetail> {
  late final PageController _controller =
      PageController(initialPage: widget.index);
  late int _current = widget.index;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _download(Wallpaper wp) async {
    final ok = await ref.read(galleryServiceProvider).saveAsset(wp.image);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(ok ? 'wallpapers.saved'.tr() : 'wallpapers.saveError'.tr())));
  }

  /// "Duvar Kâğıdı Yap" — hedef seç (ana ekran / kilit / ikisi), sonra ayarla.
  Future<void> _setWallpaper(Wallpaper wp) async {
    final target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF12161F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('wallpapers.setAs'.tr(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            for (final o in const [
              ('home', Icons.home_rounded, 'wallpapers.home'),
              ('lock', Icons.lock_rounded, 'wallpapers.lock'),
              ('both', Icons.smartphone_rounded, 'wallpapers.both'),
            ])
              ListTile(
                leading: Icon(o.$2, color: AppColors.goldBright),
                title:
                    Text(o.$3.tr(), style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop(o.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('wallpapers.settingWp'.tr())));
    final ok =
        await ref.read(galleryServiceProvider).setWallpaper(wp.image, target);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(ok ? 'wallpapers.wpSet'.tr() : 'wallpapers.saveError'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final wp = widget.list[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Swipe left/right through the whole wallpaper list.
          PageView.builder(
            controller: _controller,
            itemCount: widget.list.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => AppImage.cdn(widget.list[i].image,
                fallbackColors: widget.list[i].colors),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Colors.transparent,
                    Color(0xCC000000)
                  ],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(AppIcons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const Spacer(),
                Text(wp.title(lang),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${_current + 1} / ${widget.list.length}',
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 13)),
                const Gap.lg(),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _LikeAction(id: wp.id),
                      _Action(
                        icon: AppIcons.download,
                        label: 'common.download'.tr(),
                        onTap: () => _download(wp),
                      ),
                      _Action(
                        icon: Icons.wallpaper_rounded,
                        label: 'wallpapers.setAsShort'.tr(),
                        onTap: () => _setWallpaper(wp),
                      ),
                      _Action(
                        icon: AppIcons.share,
                        label: 'common.share'.tr(),
                        onTap: () => SharePlus.instance.share(ShareParams(
                            text:
                                '${wp.title(lang)} • SELAYA — ${'common.slogan'.tr()}')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? activeColor;
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon,
                color: active
                    ? (activeColor ?? AppColors.goldBright)
                    : Colors.white,
                size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Detayda BEĞENİ aksiyonu — sunucu sayacı (açılışta `likesProvider`'dan çekilir).
class _LikeAction extends ConsumerWidget {
  final String id;
  const _LikeAction({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = 'wallpaper:$id';
    final liked = ref.watch(likedKeysProvider).contains(key);
    // LikeButton ile AYNI formül → ızgaradaki sayı ile detaydaki sayı eşit.
    final server = ref.watch(likesProvider).asData?.value[key] ?? 0;
    final count = likeSeed(key) + server + (liked ? 1 : 0);
    return _Action(
      icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      label: count > 0 ? '${'common.like'.tr()} · $count' : 'common.like'.tr(),
      active: liked,
      activeColor: const Color(0xFFE57373),
      onTap: liked
          ? null
          : () {
              HapticFeedback.lightImpact();
              ref.read(likedKeysProvider.notifier).like(key);
            },
    );
  }
}
