import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';

/// "Medya" — ana ekrandan toplanan görsel kısayollar (duvar kâğıtları, videolar,
/// tebrik kartları). Ana ekran sade kalsın diye bunlar ayrı bölümler yerine tek
/// "Medya" kartından açılan bu sayfada toplanır (kullanıcı isteği 2026-06-14).
class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    final items = <_MediaItem>[
      _MediaItem(
        icon: AppIcons.wallpaper,
        title: 'wallpapers.title'.tr(),
        desc: tr ? 'Günlük İslami duvar kâğıtları' : 'Daily Islamic wallpapers',
        route: Routes.wallpapers,
      ),
      _MediaItem(
        icon: AppIcons.play,
        title: 'home.videos'.tr(),
        desc: tr ? 'Kısa videolar ve akış' : 'Short videos and reels',
        route: Routes.feed,
      ),
      _MediaItem(
        icon: AppIcons.card,
        title: 'greetings.title'.tr(),
        desc: tr ? 'Sevdiklerine özel kartlar' : 'Special cards for loved ones',
        route: Routes.greetings,
      ),
    ];
    return SelayaScaffold(
      title: tr ? 'Medya' : 'Media',
      showBack: true,
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xxxl),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Gap.sm(),
        itemBuilder: (context, i) => _MediaTile(item: items[i]),
      ),
    );
  }
}

class _MediaItem {
  final IconData icon;
  final String title;
  final String desc;
  final String route;
  const _MediaItem({
    required this.icon,
    required this.title,
    required this.desc,
    required this.route,
  });
}

class _MediaTile extends StatelessWidget {
  final _MediaItem item;
  const _MediaTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: () => context.push(item.route),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: c.gold.withValues(alpha: 0.14)),
            child: Icon(item.icon, color: c.gold, size: 22),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(item.desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textTertiary),
        ],
      ),
    );
  }
}
