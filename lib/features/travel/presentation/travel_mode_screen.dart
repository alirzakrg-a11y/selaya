import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../guides/domain/travel_basics.dart';
import '../../guides/presentation/guide_widgets.dart';

/// Seferî (seyahat) modu — kullanıcı yolculuktayken namazların kısaltılması
/// (kasr) ve diğer seferîlik hükümlerini gösterir. Durum cihazda saklanır
/// (senkronlanmaz); tamamen offline, bilgilendirici bir ekran.
class TravelModeController extends Notifier<bool> {
  static const _key = 'travel_mode';
  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? false;
  Future<void> toggle(bool v) async {
    await ref.read(sharedPreferencesProvider).setBool(_key, v);
    state = v;
  }
}

final travelModeProvider =
    NotifierProvider<TravelModeController, bool>(TravelModeController.new);

class _Prayer {
  final String name;
  final String normal;
  final String travel;
  final bool changes;
  const _Prayer(this.name, this.normal, this.travel, this.changes);
}

class TravelModeScreen extends ConsumerWidget {
  const TravelModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final tr = lang == 'tr';
    final c = context.colors;
    final on = ref.watch(travelModeProvider);

    final prayers = tr
        ? const [
            _Prayer('Sabah', '2 farz', '2 farz', false),
            _Prayer('Öğle', '4 farz', '2 farz', true),
            _Prayer('İkindi', '4 farz', '2 farz', true),
            _Prayer('Akşam', '3 farz', '3 farz', false),
            _Prayer('Yatsı', '4 farz', '2 farz', true),
          ]
        : const [
            _Prayer('Fajr', '2 fard', '2 fard', false),
            _Prayer('Dhuhr', '4 fard', '2 fard', true),
            _Prayer('Asr', '4 fard', '2 fard', true),
            _Prayer('Maghrib', '3 fard', '3 fard', false),
            _Prayer('Isha', '4 fard', '2 fard', true),
          ];

    return SelayaScaffold(
      title: 'travel.title'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          const _Header(),
          const Gap.md(),
          Row(children: [
            Expanded(
                child: GuideQuickLink(
                    icon: Icons.self_improvement_rounded,
                    label: 'xt.tvLinkSalah'.tr(),
                    onTap: () => context.push(Routes.namazGuide))),
            const Gap.sm(),
            Expanded(
                child: GuideQuickLink(
                    icon: Icons.explore_rounded,
                    label: 'xt.tvLinkQibla'.tr(),
                    onTap: () => context.go(Routes.qibla))),
            const Gap.sm(),
            Expanded(
                child: GuideQuickLink(
                    icon: Icons.schedule_rounded,
                    label: 'xt.tvLinkTimes'.tr(),
                    onTap: () => context.go(Routes.times))),
          ]),
          const Gap.lg(),

          // Durum kartı (aç/kapat)
          SelayaCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        (on ? c.gold : c.textTertiary).withValues(alpha: 0.16),
                  ),
                  child: Icon(Icons.flight_rounded,
                      color: on ? c.gold : c.textTertiary),
                ),
                const Gap.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        on
                            ? 'xt.tvStatusOn'.tr()
                            : 'xt.tvStatusOff'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Gap.xxs(),
                      Text(
                        on
                            ? 'xt.tvStatusOnDesc'.tr()
                            : 'xt.tvStatusOffDesc'.tr(),
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: on,
                  onChanged: (v) =>
                      ref.read(travelModeProvider.notifier).toggle(v),
                ),
              ],
            ),
          ),
          const Gap.md(),

          // Rekât tablosu
          SelayaCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'xt.tvTableTitle'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800, color: c.gold),
                ),
                const Gap.sm(),
                Row(
                  children: [
                    const Expanded(flex: 3, child: SizedBox()),
                    Expanded(
                      flex: 2,
                      child: Text('xt.tvColNormal'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('xt.tvColTravel'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: c.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const Gap.xs(),
                for (final p in prayers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(p.name,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(p.normal,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 13)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: p.changes && on
                                  ? c.gold.withValues(alpha: 0.16)
                                  : Colors.transparent,
                              borderRadius: AppRadius.rSm,
                            ),
                            child: Text(p.travel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: p.changes ? c.gold : c.textSecondary,
                                    fontSize: 13,
                                    fontWeight: p.changes
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Gap.xs(),
                Text(
                  'xt.tvTableNote'.tr(),
                  style: TextStyle(color: c.textTertiary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const Gap.lg(),

          // Seferîlik hükümleri (kart kart)
          GuideSectionLabel('xt.tvRulingsLabel'.tr()),
          const Gap.sm(),
          for (final r in travelRules) ...[
            _RuleCard(rule: r, lang: lang),
            const Gap.sm(),
          ],
          const Gap.sm(),
          GuideSourceNote('xt.tvSourceNote'.tr()),
        ],
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
          Icon(Icons.flight_takeoff_rounded, color: c.onGold, size: 28),
          const Gap.base(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('xt.tvHeaderTitle'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: c.onGold, fontWeight: FontWeight.w800)),
                const Gap.xxs(),
                Text(
                    'xt.tvHeaderSubtitle'.tr(),
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

/// Tek bir seferîlik hükmü kartı (ikon + başlık + açıklama).
class _RuleCard extends StatelessWidget {
  final TravelRule rule;
  final String lang;
  const _RuleCard({required this.rule, required this.lang});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: c.gold.withValues(alpha: 0.13)),
            child: Icon(rule.icon, color: c.gold, size: 20),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.title(lang),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Gap.xs(),
                Text(rule.desc(lang),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.textSecondary, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
