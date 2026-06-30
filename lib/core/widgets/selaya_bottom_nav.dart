import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../ads/ad_widgets.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';

class SelayaNavItem {
  final IconData icon;
  final String labelKey;
  const SelayaNavItem(this.icon, this.labelKey);
}

const kSelayaNavItems = <SelayaNavItem>[
  SelayaNavItem(AppIcons.home, 'nav.home'),
  SelayaNavItem(AppIcons.times, 'nav.times'),
  SelayaNavItem(AppIcons.quran, 'nav.quran'),
  SelayaNavItem(AppIcons.qibla, 'nav.qibla'),
  SelayaNavItem(Icons.dynamic_feed_rounded, 'nav.akis'),
  SelayaNavItem(AppIcons.more, 'nav.more'),
];

/// Alt menü sekmelerinin rotaları — kSelayaNavItems ile AYNI sıra. Detay
/// (tam-ekran) ekranlarda SelayaBottomNav bunlarla context.go yapar; böylece
/// o şubeye geçilir + alt menü her yerde görünür kalır.
const kNavBranchRoutes = <String>[
  Routes.home,
  Routes.times,
  Routes.quran,
  Routes.qibla,
  Routes.akis,
  Routes.more,
];

/// Custom frosted bottom navigation with a gold active state.
class SelayaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SelayaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Sabit reklam: alt menünün hemen ÜSTÜNDE → alt menünün göründüğü TÜM
    // ekranlarda (Kur'an okuyucu dahil). Kur'an'da TAM EKRAN/geçiş reklamı YOK
    // (AdInterstitialObserver atlama listesi). adsActive değilse (premium/kapalı)
    // AdBanner kendini gizler → hiç yer kaplamaz.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AdBanner(),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: c.isDark ? 0.72 : 0.86),
                border: Border(top: BorderSide(color: c.border)),
              ),
              padding: EdgeInsets.only(
                top: AppSpacing.sm,
                bottom:
                    MediaQuery.viewPaddingOf(context).bottom + AppSpacing.sm,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < kSelayaNavItems.length; i++)
                    _NavButton(
                      item: kSelayaNavItems[i],
                      active: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final SelayaNavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.gold : c.textTertiary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.1 : 1,
                duration: const Duration(milliseconds: 200),
                child: Icon(item.icon, size: 24, color: color),
              ),
              const SizedBox(height: 4),
              // Keep the label on a single line and shrink it to fit so large
              // font sizes never break the bar (it's chrome, not content).
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.labelKey.tr(),
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
