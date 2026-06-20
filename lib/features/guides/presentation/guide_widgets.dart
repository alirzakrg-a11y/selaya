import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../domain/basic_item.dart';

/// Rehber ekranlarında ortak kullanılan parçalar (Namaz/Abdest rehberleri).

/// Altın bölüm başlığı.
class GuideSectionLabel extends StatelessWidget {
  final String text;
  const GuideSectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.colors.gold,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700)),
      );
}

/// Altın gradyanlı vurgulu kart — adım adım rehbere/ana eyleme yönlendirir.
class GuideHero extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const GuideHero(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: onTap,
      gradient: LinearGradient(colors: c.goldGradient),
      child: Row(
        children: [
          Icon(icon, color: c.onGold, size: 26),
          const Gap.base(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: c.onGold, fontWeight: FontWeight.w800)),
                const Gap.xxs(),
                Text(subtitle,
                    style: TextStyle(
                        color: c.onGold.withValues(alpha: 0.75), fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: c.onGold),
        ],
      ),
    );
  }
}

/// Küçük hızlı-erişim kartı (ilgili özelliklere link).
class GuideQuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const GuideQuickLink(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: onTap,
      borderRadius: AppRadius.rLg,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: c.gold.withValues(alpha: 0.13)),
            child: Icon(icon, color: c.gold, size: 19),
          ),
          const Gap.xs(),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Başlığa dokununca açılan kart — numaralı [items] listesi VEYA serbest [body].
class GuideExpandCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String lang;
  final List<BasicItem>? items;
  final String? body;
  const GuideExpandCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.lang,
    this.items,
    this.body,
  });
  @override
  State<GuideExpandCard> createState() => _GuideExpandCardState();
}

class _GuideExpandCardState extends State<GuideExpandCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = widget.items;
    return SelayaCard(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.gold.withValues(alpha: 0.13)),
                child: Icon(widget.icon, color: c.gold, size: 18),
              ),
              const Gap.sm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Gap.xxs(),
                    Text(
                        items != null
                            ? '${items.length} ${widget.lang == 'tr' ? 'madde' : 'items'} · ${widget.subtitle}'
                            : widget.subtitle,
                        style: TextStyle(color: c.textTertiary, fontSize: 11.5)),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: c.gold),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: items != null
                  ? Column(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    i == items.length - 1 ? 0 : AppSpacing.md),
                            child: _ItemRow(
                                index: i + 1,
                                item: items[i],
                                lang: widget.lang),
                          ),
                      ],
                    )
                  : Text(widget.body ?? '',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: c.textSecondary, height: 1.5)),
            ),
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final int index;
  final BasicItem item;
  final String lang;
  const _ItemRow(
      {required this.index, required this.item, required this.lang});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final desc = item.desc(lang);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: c.gold.withValues(alpha: 0.14)),
          child: Text('$index',
              style: TextStyle(
                  color: c.gold, fontWeight: FontWeight.w800, fontSize: 11)),
        ),
        const Gap.sm(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title(lang),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (desc.isNotEmpty) ...[
                const Gap.xxs(),
                Text(desc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary, height: 1.4)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Kaynak/uyarı notu kutusu.
class GuideSourceNote extends StatelessWidget {
  final String text;
  const GuideSourceNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.gold.withValues(alpha: 0.08),
        borderRadius: AppRadius.rSm,
        border: Border.all(color: c.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, size: 16, color: c.gold),
          const Gap.sm(),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
