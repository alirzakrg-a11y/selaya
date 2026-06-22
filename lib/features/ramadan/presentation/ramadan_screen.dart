import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../core/localization/localized_text.dart';
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
    final tr = context.langCode == 'tr';
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
      title: tr ? 'Ramazan' : 'Ramadan',
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
            cdLabel = tr ? 'Sahur (imsak) bitişine' : 'To suhoor (imsak)';
            cdIcon = Icons.bedtime_rounded;
          } else if (now.isBefore(t.maghrib)) {
            target = t.maghrib;
            cdLabel = tr ? 'İftara kalan' : 'To iftar';
            cdIcon = Icons.restaurant_rounded;
          } else {
            target = t.imsak.add(const Duration(days: 1));
            cdLabel = tr ? 'Sahura (imsak) kalan' : 'To suhoor';
            cdIcon = Icons.bedtime_rounded;
          }
          final remaining = target.difference(now);

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
                            ? '🌙 ${tr ? 'Ramazan' : 'Ramadan'} · $ramadanDay. ${tr ? 'gün' : 'day'}'
                            : '🌙 ${tr ? 'Ramazan\'a' : 'To Ramadan'} $daysToRamadan ${tr ? 'gün' : 'days'}',
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
                      Text(tr ? 'gün kaldı' : 'days left',
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
                    const Gap.md(),
                    // İmsak / İftar saatleri
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _timeChip(c, Icons.bedtime_rounded,
                            tr ? 'İmsak' : 'Suhoor', _hm(t.imsak)),
                        Container(
                            width: 1, height: 34, color: c.border),
                        _timeChip(c, Icons.restaurant_rounded,
                            tr ? 'İftar' : 'Iftar', _hm(t.maghrib)),
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
                          Text(tr ? 'Mukabele' : 'Mukabala',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                              isRamadan
                                  ? (tr
                                      ? 'Bugünün cüzü: $juz. cüz — oku'
                                      : "Today's juz: $juz — read")
                                  : (tr
                                      ? 'Her gün bir cüz oku (1. cüzden başla)'
                                      : 'Read one juz a day (start at juz 1)'),
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
                      Text(tr ? 'İFTAR DUASI' : 'IFTAR DUA',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: c.gold,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700)),
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
                      tr
                          ? '"Allah\'ım! Senin (rızan) için oruç tuttum ve senin rızkınla orucumu açtım."'
                          : '"O Allah! For You I fasted and with Your provision I broke my fast."',
                      style: TextStyle(color: c.textPrimary, height: 1.45),
                    ),
                    const Gap.sm(),
                    Text(
                      tr
                          ? 'Sahur niyeti: "Niyet ettim Allah rızası için yarınki Ramazan orucunu tutmaya."'
                          : 'Suhoor intention: "I intend to fast tomorrow\'s Ramadan fast for the sake of Allah."',
                      style: TextStyle(
                          color: c.textTertiary, fontSize: 12.5, height: 1.4),
                    ),
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
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
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
}

/// Bugün oruç tuttum işaretleme — fasting_tracking deposunu kullanır.
class _FastToggle extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FastToggle> createState() => _FastToggleState();
}

class _FastToggleState extends ConsumerState<_FastToggle> {
  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    final c = context.colors;
    final store = ref.watch(fastingStoreProvider);
    final wm = ref.watch(womensModeProvider);
    final today = DateTime.now();
    final fasted = store.statusFor(today) == FastStatus.fasted;
    final streak = store.streak(wm);
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
                        ? (tr ? 'Bugün oruçlusun ✓' : "You're fasting today ✓")
                        : (tr ? 'Bugün oruç tuttun mu?' : 'Did you fast today?'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                    streak > 0
                        ? (tr
                            ? '🔥 $streak günlük seri'
                            : '🔥 $streak-day streak')
                        : (tr
                            ? 'İşaretlemek için dokun'
                            : 'Tap to mark'),
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
