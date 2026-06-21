import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';

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
    final tr = context.langCode == 'tr';
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

    final rules = tr
        ? const [
            (
              Icons.route_rounded,
              'Ne zaman seferî olunur?',
              'Yaklaşık 90 km (yaklaşık 18 saatlik yürüme mesafesi) ve daha uzağa, '
                  'gittiği yerde 15 günden az kalma niyetiyle çıkıldığında kişi '
                  'seferî (yolcu) sayılır.'
            ),
            (
              Icons.self_improvement_rounded,
              'Namaz nasıl kılınır?',
              'Dört rekâtlı farzlar (öğle, ikindi, yatsı) iki rekât olarak kılınır '
                  '(kasr). Sabah ve akşamın farzları değişmez. Yolda iken öğle, '
                  'ikindi ve yatsının sünnetleri terk edilebilir; sabahın sünneti '
                  'ise kılınır.'
            ),
            (
              Icons.layers_rounded,
              'Cem (birleştirme)',
              'Hanefî mezhebine göre Arafat ve Müzdelife dışında namazlar vakitleri '
                  'birleştirilerek kılınmaz. Zaruret hâlinde, Diyanet seferde namazların '
                  'cem edilmesine cevaz vermektedir.'
            ),
            (
              Icons.front_hand_rounded,
              'Mest üzerine mesh',
              'Yolcu, abdestte mestleri üzerine 3 gün (72 saat) mesh edebilir. '
                  'Mukim (yolcu olmayan) için bu süre 1 gündür (24 saat).'
            ),
            (
              Icons.no_food_rounded,
              'Oruç',
              'Yolcu Ramazan orucunu tutmayıp sonra kaza edebilir. Güç yetiriyor ve '
                  'zorlanmıyorsa tutması daha faziletlidir.'
            ),
          ]
        : const [
            (
              Icons.route_rounded,
              'When do you become a traveler?',
              'You are considered a traveler (musafir) when you set out to a place '
                  'about 90 km or farther, intending to stay there fewer than 15 days.'
            ),
            (
              Icons.self_improvement_rounded,
              'How to pray',
              'The four-rakat obligatory prayers (Dhuhr, Asr, Isha) are shortened to '
                  'two rakats (qasr). Fajr and Maghrib are unchanged. While travelling '
                  'the sunnahs of Dhuhr, Asr and Isha may be omitted; the Fajr sunnah '
                  'is kept.'
            ),
            (
              Icons.layers_rounded,
              'Combining (jam‘)',
              'In the Hanafi school prayers are not combined except at Arafat and '
                  'Muzdalifah. In case of necessity, Diyanet permits combining prayers '
                  'while travelling.'
            ),
            (
              Icons.front_hand_rounded,
              'Wiping over socks (masah)',
              'A traveler may wipe over leather socks for 3 days (72 hours) in wudu, '
                  'versus 1 day (24 hours) for a resident.'
            ),
            (
              Icons.no_food_rounded,
              'Fasting',
              'A traveler may postpone the Ramadan fast and make it up later. If able '
                  'and not in hardship, fasting is more virtuous.'
            ),
          ];

    return SelayaScaffold(
      title: 'travel.title'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          // Durum kartı (aç/kapat)
          SelayaCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (on ? c.gold : c.textTertiary)
                        .withValues(alpha: 0.16),
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
                            ? (tr ? 'Seferî moddasınız' : 'Travel mode on')
                            : (tr ? 'Mukim (normal)' : 'Resident (normal)'),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Gap.xxs(),
                      Text(
                        on
                            ? (tr
                                ? '4 rekâtlı farzları 2 kılın'
                                : 'Pray 4-rakat fards as 2')
                            : (tr
                                ? 'Yolculuğa çıkınca açın'
                                : 'Turn on when you travel'),
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
                  tr ? 'Farz rekât sayıları' : 'Obligatory rakat counts',
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
                      child: Text(tr ? 'Normal' : 'Normal',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(tr ? 'Seferî' : 'Travel',
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
                  tr
                      ? 'Vitir ve sünnetler ayrıdır; tabloda yalnızca farzlar gösterilir.'
                      : 'Witr and sunnahs are separate; only fard prayers are shown.',
                  style: TextStyle(color: c.textTertiary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const Gap.md(),
          for (final r in rules) ...[
            SelayaCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(r.$1, color: c.gold, size: 22),
                  const Gap.md(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.$2,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const Gap.xs(),
                        Text(r.$3,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: c.textSecondary, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap.sm(),
          ],
          const Gap.sm(),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.08),
              borderRadius: AppRadius.rMd,
              border: Border.all(color: c.gold.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book_rounded, color: c.gold, size: 18),
                const Gap.sm(),
                Expanded(
                  child: Text(
                    tr
                        ? 'Bilgiler Hanefî mezhebi ve Diyanet İşleri Başkanlığı esas alınarak '
                            'hazırlanmıştır. Tereddüt hâlinde bir din görevlisine danışınız.'
                        : 'Information is based on the Hanafi school and Diyanet. When in '
                            'doubt, consult a scholar.',
                    style: TextStyle(
                        color: c.textTertiary, fontSize: 11.5, height: 1.4),
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
