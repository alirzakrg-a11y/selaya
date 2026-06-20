import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../domain/prayer_basics.dart';
import '../domain/prayer_types.dart';

/// Namaz Rehberi hub'ı — adım adım "Namaz nasıl kılınır" + hızlı erişim
/// (abdest/kıble/vakitler) + namazın temelleri (şartları, rükünleri, bozan
/// şeyler, secde-i sehv) + kategorize namaz çeşitleri.
class NamazRehberiScreen extends StatelessWidget {
  const NamazRehberiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.langCode;
    final tr = lang == 'tr';
    final cats = tr ? prayerCategoriesTr : prayerCategoriesEn;
    return SelayaScaffold(
      title: 'more.namazGuide'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          // Adım adım görselli rehber.
          SelayaCard(
            onTap: () => context.push(Routes.namazHowTo),
            gradient: LinearGradient(colors: c.goldGradient),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: c.onGold, size: 26),
                const Gap.base(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr ? 'Namaz Nasıl Kılınır?' : 'How to Pray (Step by Step)',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: c.onGold, fontWeight: FontWeight.w800)),
                      const Gap.xxs(),
                      Text(
                          tr
                              ? 'Adım adım görselli anlatım'
                              : 'Illustrated step-by-step walkthrough',
                          style: TextStyle(
                              color: c.onGold.withValues(alpha: 0.75),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: c.onGold),
              ],
            ),
          ),
          const Gap.md(),
          // Hızlı erişim — namazın ön hazırlıkları.
          Row(
            children: [
              Expanded(
                child: _QuickLink(
                    icon: Icons.water_drop_rounded,
                    label: tr ? 'Abdest' : 'Wudu',
                    onTap: () => context.push(Routes.abdestGuide)),
              ),
              const Gap.sm(),
              Expanded(
                child: _QuickLink(
                    icon: Icons.explore_rounded,
                    label: tr ? 'Kıble' : 'Qibla',
                    onTap: () => context.push(Routes.qibla)),
              ),
              const Gap.sm(),
              Expanded(
                child: _QuickLink(
                    icon: Icons.schedule_rounded,
                    label: tr ? 'Vakitler' : 'Times',
                    onTap: () => context.push(Routes.times)),
              ),
            ],
          ),
          const Gap.lg(),
          // Namazın temelleri (açılır kartlar).
          _SectionLabel(tr ? 'NAMAZIN TEMELLERİ' : 'FUNDAMENTALS'),
          const Gap.sm(),
          _ExpandCard(
            icon: Icons.checklist_rounded,
            title: tr ? 'Namazın Şartları' : 'Conditions of Prayer',
            subtitle: tr ? 'Namaza başlamadan önce' : 'Before starting',
            items: namazSartlari,
            lang: lang,
          ),
          const Gap.sm(),
          _ExpandCard(
            icon: Icons.account_tree_rounded,
            title: tr ? 'Namazın Rükünleri' : 'Pillars of Prayer',
            subtitle: tr ? 'Namazın içindeki farzlar' : 'Within the prayer',
            items: namazRukunleri,
            lang: lang,
          ),
          const Gap.sm(),
          _ExpandCard(
            icon: Icons.report_gmailerrorred_rounded,
            title: tr ? 'Namazı Bozan Şeyler' : 'What Invalidates Prayer',
            subtitle: tr ? 'Kaçınılması gerekenler' : 'Things to avoid',
            items: namaziBozanlar,
            lang: lang,
          ),
          const Gap.sm(),
          _ExpandCard(
            icon: Icons.healing_rounded,
            title: tr ? 'Secde-i Sehv' : 'Sajdah of Forgetfulness',
            subtitle: tr ? 'Yanılma durumunda' : 'When you err',
            body: tr ? secdeSehvTr : secdeSehvEn,
            lang: lang,
          ),
          const Gap.lg(),
          // Namaz çeşitleri (kategorize).
          for (final cat in prayerCategoryOrder) ...[
            _SectionLabel((cats[cat] ?? cat).toUpperCase()),
            const Gap.sm(),
            for (final p in prayerTypes.where((p) => p.category == cat)) ...[
              _PrayerTypeCard(p: p, lang: lang),
              const Gap.sm(),
            ],
            const Gap.md(),
          ],
          // Kaynak.
          Container(
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
                  child: Text(
                      tr
                          ? 'Kaynak: Diyanet İşleri Başkanlığı İlmihali esas alınmıştır. Ayrıntı için yetkili kaynaklara başvurun.'
                          : 'Source: based on the Diyanet catechism. Consult qualified sources for detail.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textSecondary, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
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

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLink(
      {required this.icon, required this.label, required this.onTap});

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
              shape: BoxShape.circle,
              color: c.gold.withValues(alpha: 0.13),
            ),
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

/// Başlığa dokununca açılan kart — numaralı madde listesi VEYA serbest metin.
class _ExpandCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String lang;
  final List<BasicItem>? items;
  final String? body;
  const _ExpandCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.lang,
    this.items,
    this.body,
  });
  @override
  State<_ExpandCard> createState() => _ExpandCardState();
}

class _ExpandCardState extends State<_ExpandCard> {
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
                                bottom: i == items.length - 1 ? 0 : AppSpacing.md),
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
            shape: BoxShape.circle,
            color: c.gold.withValues(alpha: 0.14),
          ),
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

class _PrayerTypeCard extends StatelessWidget {
  final PrayerType p;
  final String lang;
  const _PrayerTypeCard({required this.p, required this.lang});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      patterned: true,
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
                child: Icon(p.icon, color: c.gold, size: 18),
              ),
              const Gap.sm(),
              Expanded(
                child: Text(p.name(lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const Gap.sm(),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: c.gold.withValues(alpha: 0.12),
                  borderRadius: AppRadius.rSm,
                  border: Border.all(color: c.gold.withValues(alpha: 0.3))),
              child: Text(p.rakats,
                  style: TextStyle(
                      color: c.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const Gap.sm(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_rounded, size: 13, color: c.textTertiary),
              const Gap.xs(),
              Expanded(
                child: Text(p.whenText(lang),
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ),
            ],
          ),
          const Gap.xs(),
          Text(p.desc(lang),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(height: 1.45, color: c.textSecondary)),
        ],
      ),
    );
  }
}
