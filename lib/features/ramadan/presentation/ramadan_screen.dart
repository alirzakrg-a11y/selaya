import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../fasting_tracking/data/fasting_controller.dart';
import '../../fasting_tracking/domain/fasting_day.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../womens_mode/data/womens_mode_controller.dart';

/// "Ramazan" — sahur/iftar canlı geri sayım + Ramazan günü + mukabele (günün
/// cüzü) + oruç işaretleme + iftar duası. Ramazan dışında "Ramazan'a X gün"
/// geri sayımı gösterir; yine de oruç saatleri (sünnet/kaza için) kullanılır.
class RamadanScreen extends ConsumerStatefulWidget {
  const RamadanScreen({super.key});
  @override
  ConsumerState<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends ConsumerState<RamadanScreen> {
  static const _trMonths = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _dur(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final timesAsync = ref.watch(dailyTimesProvider);
    final offset = ref.watch(hijriOffsetProvider);

    final h = HijriCalendar.fromDate(now.add(Duration(days: offset)));
    final isRamadan = h.hMonth == 9;
    final ramadanDay = h.hDay;
    int daysToRamadan = 0;
    DateTime? ram1;
    if (!isRamadan) {
      final cal = HijriCalendar();
      final hy = h.hMonth < 9 ? h.hYear : h.hYear + 1;
      ram1 = cal.hijriToGregorian(hy, 9, 1);
      daysToRamadan =
          ram1.difference(DateTime(now.year, now.month, now.day)).inDays;
    }

    return SelayaScaffold(
      title: 'xt.rmTitle'.tr(),
      showBack: true,
      body: timesAsync.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (t) {
          // Sahur/iftar hedefi: imsaktan önce → sahur bitişi; gündüz → iftar;
          // iftardan sonra → (yaklaşık) yarınki sahur.
          DateTime target;
          String cdLabel;
          IconData cdIcon;
          if (now.isBefore(t.imsak)) {
            target = t.imsak;
            cdLabel = 'xt.rmCountdownSuhoorEnd'.tr();
            cdIcon = Icons.bedtime_rounded;
          } else if (now.isBefore(t.maghrib)) {
            target = t.maghrib;
            cdLabel = 'xt.rmCountdownToIftar'.tr();
            cdIcon = Icons.restaurant_rounded;
          } else {
            target = t.imsak.add(const Duration(days: 1));
            cdLabel = 'xt.rmCountdownToSuhoor'.tr();
            cdIcon = Icons.bedtime_rounded;
          }
          final remaining = target.difference(now);
          // Oruç ilerlemesi (imsak→iftar arası gündüz) — görsel çubuk için.
          double? fastProgress;
          if (now.isAfter(t.imsak) && now.isBefore(t.maghrib)) {
            final total = t.maghrib.difference(t.imsak).inSeconds;
            fastProgress = total > 0
                ? (now.difference(t.imsak).inSeconds / total).clamp(0.0, 1.0)
                : null;
          }

          final juz = (isRamadan ? ramadanDay : 1).clamp(1, 30);
          final juzPage = ((juz - 1) * 20 + 1).clamp(1, 604);

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md,
                AppSpacing.base, AppSpacing.xxxl),
            children: [
              // ── HERO ──
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.rXl,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.gold.withValues(alpha: 0.28), c.surfaceAlt],
                  ),
                  border: Border.all(color: c.gold.withValues(alpha: 0.32)),
                ),
                child: Column(
                  children: [
                    // Durum rozeti
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        isRamadan
                            ? 'xt.rmBadgeDay'.tr(args: [ramadanDay.toString()])
                            : 'xt.rmBadgeCountdown'
                                .tr(args: [daysToRamadan.toString()]),
                        style: TextStyle(
                            color: c.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 13),
                      ),
                    ),
                    const Gap.md(),
                    if (isRamadan) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(cdIcon, color: c.gold, size: 18),
                          const SizedBox(width: 6),
                          Text(cdLabel,
                              style: TextStyle(
                                  color: c.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Gap.xs(),
                      Text(_dur(remaining),
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 46,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              height: 1.05)),
                    ] else ...[
                      Text('$daysToRamadan',
                          style: TextStyle(
                              color: c.gold,
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              height: 1)),
                      Text('xt.rmDaysLeft'.tr(),
                          style: TextStyle(color: c.textSecondary)),
                      if (ram1 != null) ...[
                        const Gap.xs(),
                        Text(
                          '${ram1.day} ${_trMonths[ram1.month - 1]} ${ram1.year}',
                          style: TextStyle(
                              color: c.textTertiary, fontSize: 12.5),
                        ),
                      ],
                    ],
                    // Oruç ilerleme çubuğu (gündüz)
                    if (fastProgress != null) ...[
                      const Gap.md(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('xt.rmFastProgress'.tr(),
                                    style: TextStyle(
                                        color: c.textSecondary, fontSize: 12)),
                                Text('%${(fastProgress * 100).round()}',
                                    style: TextStyle(
                                        color: c.gold,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: fastProgress,
                                minHeight: 7,
                                backgroundColor: c.border,
                                valueColor: AlwaysStoppedAnimation(c.gold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Ramazan dışında: canlı sahur/iftar geri sayım pili
                    if (!isRamadan) ...[
                      const Gap.sm(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cdIcon, size: 15, color: c.gold),
                            const SizedBox(width: 6),
                            Text('$cdLabel: ',
                                style: TextStyle(
                                    color: c.textSecondary, fontSize: 12.5)),
                            Text(_dur(remaining),
                                style: TextStyle(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ])),
                          ],
                        ),
                      ),
                    ],
                    const Gap.md(),
                    // İmsak / İftar saatleri
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _timeChip(c, Icons.bedtime_rounded,
                            'xt.rmSuhoor'.tr(), _hm(t.imsak)),
                        Container(
                            width: 1, height: 34, color: c.border),
                        _timeChip(c, Icons.restaurant_rounded,
                            'xt.rmIftar'.tr(), _hm(t.maghrib)),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap.md(),
              // ── MUKABELE ──
              SelayaCard(
                onTap: () => context.push(Routes.mushaf, extra: juzPage),
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Row(
                  children: [
                    _roundIcon(c, Icons.auto_stories_rounded),
                    const Gap.md(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('xt.rmMukabala'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                              isRamadan
                                  ? 'xt.rmMukabalaTodayJuz'
                                      .tr(args: [juz.toString()])
                                  : 'xt.rmMukabalaHint'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: c.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                  ],
                ),
              ),
              const Gap.sm(),
              // ── ORUÇ İŞARETLE ──
              _FastToggle(),
              const Gap.md(),
              // ── İFTAR DUASI ──
              SelayaCard(
                patterned: true,
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.volunteer_activism_rounded,
                          size: 18, color: c.gold),
                      const SizedBox(width: 6),
                      Text('xt.rmIftarDuaHeading'.tr(),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: c.gold,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => SharePlus.instance.share(ShareParams(
                          text: 'اللَّهُمَّ لَكَ صُمْتُ وَعَلَىٰ رِزْقِكَ أَفْطَرْتُ\n\n'
                              'Allâhümme leke sumtü ve alâ rızkıke eftartü\n\n'
                              '${'xt.rmIftarDuaMeaning'.tr()}\n\nSELAYA',
                        )),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.ios_share_rounded,
                              size: 18, color: c.textSecondary),
                        ),
                      ),
                    ]),
                    const Gap.sm(),
                    Center(
                      child: Text(
                        'اللَّهُمَّ لَكَ صُمْتُ وَعَلَىٰ رِزْقِكَ أَفْطَرْتُ',
                        textAlign: TextAlign.center,
                        style:
                            AppTypography.arabic(fontSize: 24, color: c.textPrimary),
                      ),
                    ),
                    const Gap.sm(),
                    Text(
                      'Allâhümme leke sumtü ve alâ rızkıke eftartü',
                      style: TextStyle(
                          color: c.textSecondary,
                          fontStyle: FontStyle.italic,
                          fontSize: 13),
                    ),
                    const Gap.xs(),
                    Text(
                      'xt.rmIftarDuaMeaning'.tr(),
                      style: TextStyle(color: c.textPrimary, height: 1.45),
                    ),
                    const Gap.sm(),
                    Text(
                      'xt.rmSuhoorIntention'.tr(),
                      style: TextStyle(
                          color: c.textTertiary, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const Gap.md(),
              // ── RAMAZAN'DA ──
              SelayaCard(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                    AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 2),
                      child: Row(children: [
                        Icon(Icons.nightlight_round, size: 18, color: c.gold),
                        const SizedBox(width: 6),
                        Text('xt.rmInRamadanHeading'.tr(),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: c.gold,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    InkWell(
                      onTap: () => context.push(Routes.zakat),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Icon(Icons.volunteer_activism_rounded,
                              size: 19, color: c.gold),
                          const Gap.md(),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('xt.rmFitraZakat'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                Text(
                                    'xt.rmFitraZakatSub'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: c.textSecondary)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: c.textTertiary),
                        ]),
                      ),
                    ),
                    Divider(height: 1, color: c.border),
                    _infoRow(
                        c,
                        Icons.mosque_rounded,
                        'xt.rmTaraweehTitle'.tr(),
                        'xt.rmTaraweehDesc'.tr()),
                    Divider(height: 1, color: c.border),
                    _infoRow(
                        c,
                        Icons.star_rounded,
                        'xt.rmQadrTitle'.tr(),
                        'xt.rmQadrDesc'.tr()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _timeChip(dynamic c, IconData icon, String label, String time) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: c.gold, size: 18),
        const SizedBox(height: 3),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textSecondary, fontSize: 12)),
        Text(time,
            style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
      ],
    );
  }

  Widget _roundIcon(dynamic c, IconData icon) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: c.gold.withValues(alpha: 0.14)),
        child: Icon(icon, color: c.gold, size: 22),
      );

  Widget _infoRow(dynamic c, IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: c.gold),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(desc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bugün oruç tuttum işaretleme — fasting_tracking deposunu kullanır.
class _FastToggle extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FastToggle> createState() => _FastToggleState();
}

class _FastToggleState extends ConsumerState<_FastToggle> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = ref.watch(fastingStoreProvider);
    final wm = ref.watch(womensModeProvider);
    final today = DateTime.now();
    final fasted = store.statusFor(today) == FastStatus.fasted;
    final streak = store.streak(wm);
    final monthCount =
        store.countInMonth(today.year, today.month, FastStatus.fasted);
    final parts = <String>[];
    if (streak > 0) {
      parts.add('xt.rmStreak'.tr(args: [streak.toString()]));
    }
    if (monthCount > 0) {
      parts.add('xt.rmMonthCount'.tr(args: [monthCount.toString()]));
    }
    final subtitle =
        parts.isEmpty ? 'xt.rmTapToMark'.tr() : parts.join(' · ');
    return SelayaCard(
      onTap: () async {
        await store.setStatus(
            today, fasted ? FastStatus.none : FastStatus.fasted);
        if (mounted) setState(() {});
      },
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fasted ? c.success : Colors.transparent,
              border: Border.all(
                  color: fasted ? c.success : c.border, width: 2),
            ),
            child: fasted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
                : Icon(Icons.wb_twilight_rounded, color: c.gold, size: 22),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    fasted
                        ? 'xt.rmFastingToday'.tr()
                        : 'xt.rmDidYouFast'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
