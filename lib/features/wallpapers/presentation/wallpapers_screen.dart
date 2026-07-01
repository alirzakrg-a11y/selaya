import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/ads/ad_widgets.dart';
import '../../../core/ads/ads_config.dart';
import '../../../core/data/content_providers.dart';
import '../../../core/data/likes_service.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/services/gallery_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/content_report.dart';
import '../../../core/widgets/double_tap_heart_animation.dart';
import '../../../core/widgets/like_button.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';

class WallpapersScreen extends ConsumerStatefulWidget {
  const WallpapersScreen({super.key});

  @override
  ConsumerState<WallpapersScreen> createState() => _WallpapersScreenState();
}

class _WallpapersScreenState extends ConsumerState<WallpapersScreen> {
  bool _favsOnly = false; // AppBar kalbi: yalnızca beğenilenleri göster
  // Her açılışta duvar kâğıtlarını rastgele sırala. Seed ekran ömrü boyunca
  // sabit → kaydırırken/favori değişince yeniden karışmaz; tekrar açınca yeni sıra.
  final int _shuffleSeed = Random().nextInt(0x7fffffff);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wallpapers = ref.watch(wallpapersProvider);
    final liked = ref.watch(likedKeysProvider);
    final adsOn = ref.watch(adsActiveProvider);

    return SelayaScaffold(
      title: 'wallpapers.title'.tr(),
      showBack: true,
      actions: [
        IconButton(
          tooltip: _favsOnly
              ? 'xt.wpShowAllTooltip'.tr()
              : 'xt.wpShowFavoritesTooltip'.tr(),
          icon: Icon(
            _favsOnly
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: _favsOnly ? const Color(0xFFE57373) : c.gold,
          ),
          onPressed: () => setState(() => _favsOnly = !_favsOnly),
        ),
      ],
      body: wallpapers.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (allRaw) {
          // Her açılışta rastgele sıra (seed sabit → kaydırırken sabit kalır).
          final all = allRaw.toList()..shuffle(Random(_shuffleSeed));
          final list = _favsOnly
              ? all
                  .where((wp) => liked.contains('wallpaper:${wp.id}'))
                  .toList()
              : all;
          if (list.isEmpty) {
            return SelayaEmpty(
              icon: Icons.favorite_border_rounded,
              message: 'xt.wpNoFavorites'.tr(),
            );
          }
          const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.62,
          );
          // Reklamsız (premium/kapalı) → düz ızgara.
          if (!adsOn) {
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                  AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
              gridDelegate: gridDelegate,
              itemCount: list.length,
              itemBuilder: (context, i) =>
                  _WallpaperTile(list: list, index: i),
            );
          }
          // Feed içi reklam: her 4 görselde (2 satır) bir tam-genişlik yerel
          // reklam. Izgara parçalara bölünüp aralara NativeAdCard konur.
          const chunk = 4;
          final slivers = <Widget>[];
          for (var start = 0; start < list.length; start += chunk) {
            final end =
                (start + chunk) > list.length ? list.length : start + chunk;
            slivers.add(SliverPadding(
              padding: EdgeInsets.fromLTRB(AppSpacing.base,
                  start == 0 ? AppSpacing.sm : 0, AppSpacing.base, AppSpacing.md),
              sliver: SliverGrid(
                gridDelegate: gridDelegate,
                delegate: SliverChildBuilderDelegate(
                  (context, j) =>
                      _WallpaperTile(list: list, index: start + j),
                  childCount: end - start,
                ),
              ),
            ));
            if (end < list.length) {
              slivers.add(const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.base, 0, AppSpacing.base, AppSpacing.md),
                  child: NativeAdCard(),
                ),
              ));
            }
          }
          slivers.add(const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.xxxl)));
          return CustomScrollView(slivers: slivers);
        },
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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => WallpaperDetail(list: list, index: index),
        ),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.rLg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Izgara: küçük önizleme + sınırlı decode → 1000 görselde de akıcı.
            AppImage.cdn(
              wp.gridImage,
              fallbackColors: wp.colors,
              memWidth: 560,
            ),
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
                child: Icon(
                  AppIcons.crown,
                  color: AppColors.goldBright,
                  size: 18,
                ),
              ),
            // "✨ AI" rozeti — TÜM duvar kâğıtlarında (şeffaflık; risk almamak için
            // hepsi yapay zeka üretimi olarak işaretlenir).
            Positioned(
                top: 8,
                left: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 11),
                        SizedBox(width: 3),
                        Text('AI',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      wp.title(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
  late final PageController _controller = PageController(
    initialPage: widget.index,
  );
  late int _current = widget.index;
  double _dragDy = 0; // aşağı sürükleyerek kapatma

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _download(Wallpaper wp) async {
    final ok = await ref.read(galleryServiceProvider).saveAsset(wp.image);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'wallpapers.saved'.tr() : 'wallpapers.saveError'.tr(),
        ),
      ),
    );
  }

  /// "Duvar Kâğıdı Yap" — hedef seç (ana ekran / kilit / ikisi), sonra ayarla.
  Future<void> _setWallpaper(Wallpaper wp) async {
    final target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'wallpapers.setAs'.tr(),
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            for (final o in const [
              ('home', Icons.home_rounded, 'wallpapers.home'),
              ('lock', Icons.lock_rounded, 'wallpapers.lock'),
              ('both', Icons.smartphone_rounded, 'wallpapers.both'),
            ])
              ListTile(
                leading: Icon(o.$2, color: context.colors.gold),
                title: Text(
                  o.$3.tr(),
                  style: TextStyle(color: context.colors.textPrimary),
                ),
                onTap: () => Navigator.of(context).pop(o.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('wallpapers.settingWp'.tr())));
    final ok = await ref
        .read(galleryServiceProvider)
        .setWallpaper(wp.image, target);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'wallpapers.wpSet'.tr() : 'wallpapers.saveError'.tr(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    // Reklam aktifse (premium değil) → swipe akışına her 4 sayfada 1 native
    // reklam (3 duvar kâğıdı + 1 reklam). Tam-ekran/geçiş reklamı DEĞİL.
    final adsOn = ref.watch(adsActiveProvider);
    final len = widget.list.length;
    final total = adsOn ? len + (len ~/ 3) : len;
    bool adOf(int p) => adsOn && p % 4 == 3;
    int realOf(int p) => adsOn ? (p ~/ 4) * 3 + (p % 4) : p;
    final curAd = adOf(_current);
    final wp = widget.list[realOf(_current).clamp(0, len - 1)];
    final scale = (1 - (_dragDy / 1600)).clamp(0.9, 1.0);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Çift-tıkla beğen (zaten beğeniliyse geri ALMAZ; kalbi yine gösterir).
        onDoubleTap: () {
          if (curAd) return; // reklam sayfasında beğeni yok
          final cwp = widget.list[realOf(_current)];
          final key = 'wallpaper:${cwp.id}';
          if (!ref.read(likedKeysProvider).contains(key)) {
            HapticFeedback.selectionClick();
            ref.read(likedKeysProvider.notifier).toggle(key);
          }
          DoubleTapHeartAnimation.show(context);
        },
        onVerticalDragUpdate: (d) {
          final ny = (_dragDy + d.delta.dy).clamp(0.0, 700.0);
          if (ny != _dragDy) setState(() => _dragDy = ny);
        },
        onVerticalDragEnd: (d) {
          if (_dragDy > 140 || d.velocity.pixelsPerSecond.dy > 700) {
            Navigator.of(context).pop();
          } else {
            setState(() => _dragDy = 0);
          }
        },
        child: Transform.translate(
          offset: Offset(0, _dragDy),
          child: Transform.scale(
            scale: scale,
            child: Stack(
              fit: StackFit.expand,
              children: [
          // Swipe left/right through the whole wallpaper list.
          PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => adOf(i)
                ? const ColoredBox(
                    color: Colors.black,
                    child: Center(child: NativeAdCard()),
                  )
                : AppImage.cdn(
                    widget.list[realOf(i)].image,
                    fallbackColors: widget.list[realOf(i)].colors,
                  ),
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
                    Color(0xCC000000),
                  ],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(AppIcons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (!curAd)
                      IconButton(
                        icon: const Icon(Icons.flag_outlined,
                            color: Colors.white70),
                        tooltip: 'report.cta'.tr(),
                        onPressed: () => showContentReport(context,
                            key: 'wallpaper:${wp.id}',
                            type: 'wallpapers',
                            title: wp.title(lang)),
                      ),
                  ],
                ),
                const Spacer(),
                if (!curAd) ...[
                  Text(
                    wp.title(lang),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${realOf(_current) + 1} / $len',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white70, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          lang == 'tr'
                              ? 'Yapay zeka ile üretildi'
                              : 'AI-generated',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
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
                        onTap: () => SharePlus.instance.share(
                          ShareParams(
                            text:
                                '${wp.title(lang)} • SELAYA — ${'common.slogan'.tr()}',
                          ),
                        ),
                      ),
                    ],
                  ),
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
            child: Icon(
              icon,
              color: active
                  ? (activeColor ?? AppColors.goldBright)
                  : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
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
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(likedKeysProvider.notifier).toggle(key);
      },
    );
  }
}
