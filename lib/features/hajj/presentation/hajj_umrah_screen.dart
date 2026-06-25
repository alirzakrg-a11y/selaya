import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/asset_json_loader.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../guides/domain/hajj_basics.dart';
import '../../guides/presentation/guide_widgets.dart';

class HajjStep {
  final String type; // 'umre' | 'hac'
  final String title;
  final String desc;
  final String arabic;
  final String reading;
  const HajjStep(this.type, this.title, this.desc, this.arabic, this.reading);
  factory HajjStep.fromJson(Map<String, dynamic> j) => HajjStep(
    (j['t'] ?? '').toString(),
    (j['title'] ?? '').toString(),
    (j['desc'] ?? '').toString(),
    (j['ar'] ?? '').toString(),
    (j['rd'] ?? '').toString(),
  );
}

final hajjStepsProvider = FutureProvider<List<HajjStep>>(
  (ref) => ref
      .watch(assetJsonLoaderProvider)
      .loadModels('assets/data/hajj_umrah.json', HajjStep.fromJson),
);

/// Hac & Umre rehberi — çeşitler + farz/vâcip + Telbiye + adım adım menâsik +
/// menâsik sözlüğü. İçerik Diyanet İlmihali (Hanefî) esas alınarak hazırlanmıştır.
class HajjUmrahScreen extends ConsumerStatefulWidget {
  const HajjUmrahScreen({super.key});
  @override
  ConsumerState<HajjUmrahScreen> createState() => _HajjUmrahScreenState();
}

class _HajjUmrahScreenState extends ConsumerState<HajjUmrahScreen> {
  String _type = 'umre';

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final async = ref.watch(hajjStepsProvider);
    final isHac = _type == 'hac';
    return SelayaScaffold(
      title: 'hajj.title'.tr(),
      showBack: true,
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (all) {
          final steps = all.where((s) => s.type == _type).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
            children: [
              const _Header(),
              const Gap.md(),
              Row(children: [
                Expanded(
                    child: GuideQuickLink(
                        icon: Icons.explore_rounded,
                        label: 'xt.hjQiblaLink'.tr(),
                        onTap: () => context.go(Routes.qibla))),
                const Gap.sm(),
                Expanded(
                    child: GuideQuickLink(
                        icon: Icons.volunteer_activism_rounded,
                        label: 'xt.hjDuasLink'.tr(),
                        onTap: () => context.push(Routes.duas))),
                const Gap.sm(),
                Expanded(
                    child: GuideQuickLink(
                        icon: Icons.schedule_rounded,
                        label: 'xt.hjTimesLink'.tr(),
                        onTap: () => context.go(Routes.times))),
              ]),
              const Gap.lg(),
              // Umre / Hac seçimi.
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                      value: 'umre',
                      icon: const Icon(Icons.brightness_low_rounded, size: 16),
                      label: Text('xt.hjUmrahSegment'.tr())),
                  ButtonSegment(
                      value: 'hac',
                      icon: const Icon(Icons.mosque_rounded, size: 16),
                      label: Text('xt.hjHajjSegment'.tr())),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const Gap.lg(),

              // === Hac çeşitleri (yalnız hac) ===
              if (isHac) ...[
                GuideSectionLabel('xt.hjTypesLabel'.tr()),
                const Gap.sm(),
                GuideExpandCard(
                    icon: Icons.alt_route_rounded,
                    title: 'xt.hjTypesTitle'.tr(),
                    subtitle: 'İfrad · Temettü · Kırân',
                    items: hacCesitleri,
                    lang: lang),
                const Gap.lg(),
              ],

              // === Farz & vâcip ===
              GuideSectionLabel(isHac
                  ? 'xt.hjObligationsHajjLabel'.tr()
                  : 'xt.hjObligationsUmrahLabel'.tr()),
              const Gap.sm(),
              GuideExpandCard(
                  icon: Icons.verified_rounded,
                  title: isHac
                      ? 'xt.hjPillarsHajjTitle'.tr()
                      : 'xt.hjPillarsUmrahTitle'.tr(),
                  subtitle: 'xt.hjPillarsSubtitle'.tr(),
                  items: isHac ? haccinFarzlari : umreninFarzlari,
                  lang: lang),
              const Gap.sm(),
              GuideExpandCard(
                  icon: Icons.rule_rounded,
                  title: isHac
                      ? 'xt.hjRequiredHajjTitle'.tr()
                      : 'xt.hjRequiredUmrahTitle'.tr(),
                  subtitle: 'xt.hjRequiredSubtitle'.tr(),
                  items: isHac ? haccinVacipleri : umreninVacipleri,
                  lang: lang),
              const Gap.lg(),

              // === Telbiye (ortak) ===
              GuideSectionLabel('xt.hjTalbiyahLabel'.tr()),
              const Gap.sm(),
              const _TelbiyeCard(),
              const Gap.lg(),

              // === Adım adım menâsik ===
              GuideSectionLabel(
                  'xt.hjStepByStepLabel'.tr(args: [steps.length.toString()])),
              const Gap.sm(),
              if (steps.isEmpty)
                const SelayaEmpty(icon: Icons.mosque_rounded)
              else
                for (var i = 0; i < steps.length; i++) ...[
                  _StepCard(step: steps[i], index: i),
                  const Gap.sm(),
                ],
              const Gap.md(),

              // === Menâsik sözlüğü (ortak) ===
              GuideSectionLabel('xt.hjGlossaryLabel'.tr()),
              const Gap.sm(),
              GuideExpandCard(
                  icon: Icons.menu_book_rounded,
                  title: 'xt.hjGlossaryTitle'.tr(),
                  subtitle: 'xt.hjGlossarySubtitle'.tr(),
                  items: menasikTerimleri,
                  lang: lang),
              const Gap.lg(),

              GuideSourceNote('xt.hjSourceNote'.tr()),
            ],
          );
        },
      ),
    );
  }
}

/// Üst başlık — altın gradyanlı tanıtım kartı.
class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      gradient: LinearGradient(colors: c.goldGradient),
      child: Row(
        children: [
          Icon(Icons.mosque_rounded, color: c.onGold, size: 28),
          const Gap.base(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('xt.hjHeaderTitle'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: c.onGold, fontWeight: FontWeight.w800)),
                const Gap.xxs(),
                Text(
                    'xt.hjHeaderSubtitle'.tr(),
                    style: TextStyle(
                        color: c.onGold.withValues(alpha: 0.78), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Telbiye — Arapça + okunuş + meal (öne çıkan kart).
class _TelbiyeCard extends StatelessWidget {
  const _TelbiyeCard();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      gradient: LinearGradient(
        colors: [c.gold.withValues(alpha: 0.16), c.surfaceAlt],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'لَبَّيْكَ اللّٰهُمَّ لَبَّيْكَ، لَبَّيْكَ لَا شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ، لَا شَرِيكَ لَكَ',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: AppTypography.arabic(fontSize: 22, color: c.textPrimary),
          ),
          const Gap.sm(),
          Text(
            'Lebbeyk Allâhümme lebbeyk, lebbeyke lâ şerîke leke lebbeyk, inne’l-hamde ve’n-ni’mete leke ve’l-mülk, lâ şerîke lek.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.gold, fontStyle: FontStyle.italic, height: 1.4),
          ),
          const Gap.sm(),
          Text(
            'xt.hjTalbiyahMeaning'.tr(),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final HajjStep step;
  final int index;
  const _StepCard({required this.step, required this.index});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasDua = step.arabic.trim().isNotEmpty;
    return SelayaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: c.gold.withValues(alpha: 0.16),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: c.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const Gap.md(),
              Expanded(
                child: Text(
                  step.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const Gap.sm(),
          Text(
            step.desc,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
          if (hasDua) ...[
            const Gap.md(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.gold.withValues(alpha: 0.08),
                borderRadius: AppRadius.rLg,
                border: Border.all(color: c.gold.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    step.arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: AppTypography.arabic(
                      fontSize: 22,
                      color: c.textPrimary,
                    ),
                  ),
                  if (step.reading.trim().isNotEmpty) ...[
                    const Gap.sm(),
                    Text(
                      step.reading,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.gold,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
