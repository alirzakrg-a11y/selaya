import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/celebration.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../womens_mode/data/womens_mode_controller.dart';

const _prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

// Extra daily ibadah habits tracked alongside the five prayers (#11).
const _extraItems = [
  'quran',
  'dhikr',
  'sadaka',
  'salavat',
  'istighfar',
  'tesbihat',
];
const _extraIcons = {
  'quran': Icons.menu_book_rounded,
  'dhikr': Icons.radio_button_checked,
  'sadaka': Icons.volunteer_activism_rounded,
  'salavat': Icons.auto_awesome_rounded,
  'istighfar': Icons.spa_rounded,
  'tesbihat': Icons.touch_app_rounded,
};

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});
  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  String _key(DateTime d) =>
      '${PrefKeys.trackingPrefix}${d.toIso8601String().substring(0, 10)}';

  Set<String> _marks(DateTime d) =>
      (ref.read(sharedPreferencesProvider).getStringList(_key(d)) ?? const [])
          .toSet();

  void _toggle(DateTime d, String prayer) {
    final prefs = ref.read(sharedPreferencesProvider);
    final set = _marks(d);
    final wasComplete = set.length == _prayers.length;
    set.contains(prayer) ? set.remove(prayer) : set.add(prayer);
    prefs.setStringList(_key(d), set.toList());
    HapticFeedback.selectionClick();
    setState(() {});
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (isToday && !wasComplete && set.length == _prayers.length) {
      HapticFeedback.mediumImpact();
      showCelebration(context,
          title: 'tracking.celebrateTitle'.tr(),
          message: 'tracking.celebrateBody'.tr());
    }
  }

  String _extraKey(DateTime d) =>
      '${PrefKeys.trackingExtraPrefix}${d.toIso8601String().substring(0, 10)}';

  Set<String> _extraMarks(DateTime d) =>
      (ref.read(sharedPreferencesProvider).getStringList(_extraKey(d)) ??
              const [])
          .toSet();

  void _toggleExtra(String item) {
    final prefs = ref.read(sharedPreferencesProvider);
    final d = DateTime.now();
    final set = _extraMarks(d);
    final wasAll = set.length == _extraItems.length;
    set.contains(item) ? set.remove(item) : set.add(item);
    prefs.setStringList(_extraKey(d), set.toList());
    HapticFeedback.selectionClick();
    setState(() {});
    if (!wasAll && set.length == _extraItems.length) {
      HapticFeedback.mediumImpact();
      showCelebration(context,
          title: 'tracking.celebrateIbadahTitle'.tr(),
          message: 'tracking.celebrateIbadahBody'.tr());
    }
  }

  /// Completed prayers over the last 90 days (badges + stats).
  int _totalPrayers() {
    var t = 0;
    var d = DateTime.now();
    for (var i = 0; i < 90; i++) {
      t += _marks(d).length;
      d = d.subtract(const Duration(days: 1));
    }
    return t;
  }

  /// Completed prayers in the current calendar month.
  int _monthPrayers() {
    final now = DateTime.now();
    var t = 0;
    var d = now;
    while (d.month == now.month && d.year == now.year) {
      t += _marks(d).length;
      d = d.subtract(const Duration(days: 1));
    }
    return t;
  }

  int _streak(WomensMode wm) {
    var streak = 0;
    var day = DateTime.now();
    for (var i = 0; i < 365; i++) {
      // Excluded (women's-mode) days are neutral: skip without breaking the
      // streak, and without counting them as a completed day.
      if (wm.isExcluded(day)) {
        day = day.subtract(const Duration(days: 1));
        continue;
      }
      final marks = _marks(day);
      if (marks.length == _prayers.length) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.langCode;
    final today = DateTime.now();
    final week = List.generate(
        7, (i) => today.subtract(Duration(days: 6 - i)));
    final wm = ref.watch(womensModeProvider);
    final streak = _streak(wm);
    final total = _totalPrayers();
    final monthCount = _monthPrayers();
    final perfectToday = _marks(today).length == _prayers.length;
    final badges = <(String, IconData, bool)>[
      ('tracking.badgeFirst', Icons.flag_rounded, total >= 1),
      ('tracking.badge3day', Icons.bolt_rounded, streak >= 3),
      ('tracking.badgeWeek', Icons.local_fire_department_rounded, streak >= 7),
      ('tracking.badgeMonth', Icons.whatshot_rounded, streak >= 30),
      ('tracking.badge90day', Icons.military_tech_rounded, streak >= 90),
      ('tracking.badge50', Icons.star_rounded, total >= 50),
      ('tracking.badge100', Icons.workspace_premium_rounded, total >= 100),
      ('tracking.badge500', Icons.emoji_events_rounded, total >= 500),
      ('tracking.badgePerfect', Icons.verified_rounded, perfectToday),
      ('tracking.badge14day', Icons.bolt_rounded, streak >= 14),
      ('tracking.badge60day', Icons.local_fire_department_rounded, streak >= 60),
      ('tracking.badge200', Icons.shield_rounded, total >= 200),
      ('tracking.badge1000', Icons.diamond_rounded, total >= 1000),
      ('tracking.badgeYear', Icons.brightness_7_rounded, streak >= 365),
    ];

    return SelayaScaffold(
      title: 'tracking.title'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          // streak card
          SelayaCard(
            gradient: const LinearGradient(
                colors: [Color(0xFF2A1E0A), Color(0xFF3A2A12)]),
            child: Row(
              children: [
                const Icon(AppIcons.fire, color: AppColors.goldBright, size: 36),
                const Gap.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('tracking.dayStreak'.tr(args: ['$streak']),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white)),
                      Text('tracking.streak'.tr(),
                          style: const TextStyle(color: Colors.white60)),
                    ],
                  ),
                ),
                Text('$streak',
                    style: AppTypography.countdown(AppColors.goldBright,
                        fontSize: 40)),
              ],
            ),
          ),
          const Gap.lg(),
          // Bugünün ibadetleri — extra daily habits (Kur'an / Zikir / Sadaka).
          Text('tracking.todayIbadah'.tr(),
              style: Theme.of(context).textTheme.titleLarge),
          const Gap.sm(),
          SelayaCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final item in _extraItems)
                  _extraRow(item, _extraMarks(today).contains(item)),
              ],
            ),
          ),
          const Gap.lg(),
          Text('tracking.thisWeek'.tr(),
              style: Theme.of(context).textTheme.titleLarge),
          const Gap.sm(),
          SelayaCard(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: [
                // header row: prayer labels
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      const SizedBox(width: 44),
                      for (final p in _prayers)
                        Expanded(
                          child: Text('prayer.$p'.tr(),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: Theme.of(context).textTheme.labelSmall),
                        ),
                    ],
                  ),
                ),
                for (final day in week)
                  _DayRow(
                    day: day,
                    lang: lang,
                    marks: _marks(day),
                    isToday: day.day == today.day && day.month == today.month,
                    excluded: wm.isExcluded(day),
                    onToggle: (p) => _toggle(day, p),
                  ),
              ],
            ),
          ),
          const Gap.lg(),
          // Monthly summary.
          SelayaCard(
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: c.gold, size: 30),
                const Gap.md(),
                Expanded(
                  child: Text('tracking.thisMonth'.tr(),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text('$monthCount',
                    style: AppTypography.countdown(c.gold, fontSize: 34)),
              ],
            ),
          ),
          const Gap.lg(),
          // Ay-ay geçmiş takvimi (#9) — geçmiş ayları gez, güne dokun = o gün ne
          // yaptığını gör ve düzenle.
          Text(lang == 'tr' ? 'Geçmiş' : 'History',
              style: Theme.of(context).textTheme.titleLarge),
          const Gap.sm(),
          _MonthHistory(
            prayers: _prayers,
            marksOf: _marks,
            onToggle: _toggle,
          ),
          const Gap.lg(),
          // Rozetler (badges).
          Text('tracking.badges'.tr(),
              style: Theme.of(context).textTheme.titleLarge),
          const Gap.sm(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final b in badges)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: b.$3 ? c.gold.withValues(alpha: 0.14) : c.surfaceAlt,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: b.$3 ? c.gold : c.border,
                        width: b.$3 ? 1.4 : 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(b.$2,
                          size: 18, color: b.$3 ? c.gold : c.textTertiary),
                      const SizedBox(width: 6),
                      Text(b.$1.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                  color: b.$3 ? c.textPrimary : c.textTertiary,
                                  fontWeight: b.$3
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// One extra-ibadah toggle row (icon + label + check).
  Widget _extraRow(String item, bool done) {
    final c = context.colors;
    return InkWell(
      onTap: () => _toggleExtra(item),
      borderRadius: AppRadius.rMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(_extraIcons[item], color: done ? c.success : c.gold, size: 22),
            const Gap.md(),
            Expanded(
              child: Text('tracking.extra_$item'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: done ? c.textTertiary : c.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: c.textTertiary,
                      )),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? c.success : Colors.transparent,
                border: Border.all(
                    color: done ? c.success : c.border, width: 2),
              ),
              child: Icon(Icons.check_rounded,
                  size: 18, color: done ? Colors.white : Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ay-ay geçmiş takvimi — kullanıcı geçmiş ayları gezer, her günün doluluk
/// oranını (kılınan/toplam namaz) renk yoğunluğuyla görür; bir güne dokununca o
/// gün neler yaptığını görür ve düzenleyebilir (geçmişi doldurma).
class _MonthHistory extends StatefulWidget {
  final List<String> prayers;
  final Set<String> Function(DateTime) marksOf;
  final void Function(DateTime, String) onToggle;
  const _MonthHistory(
      {required this.prayers, required this.marksOf, required this.onToggle});
  @override
  State<_MonthHistory> createState() => _MonthHistoryState();
}

class _MonthHistoryState extends State<_MonthHistory> {
  late DateTime _month;
  static const _mTr = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos',
    'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _showDay(DateTime day) {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final marks = widget.marksOf(day);
          return Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${day.day} ${_mTr[day.month - 1]} ${day.year}',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const Gap.xs(),
                Text('${marks.length}/${widget.prayers.length} namaz',
                    style: TextStyle(
                        color: c.gold, fontWeight: FontWeight.w700)),
                const Gap.md(),
                for (final p in widget.prayers)
                  InkWell(
                    onTap: () {
                      widget.onToggle(day, p);
                      setSheet(() {});
                      setState(() {});
                    },
                    borderRadius: AppRadius.rMd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                              marks.contains(p)
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: marks.contains(p) ? c.gold : c.textTertiary,
                              size: 24),
                          const Gap.md(),
                          Text('prayer.$p'.tr(),
                              style: Theme.of(ctx).textTheme.titleSmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // 1=Pzt
    final canNext = _month.year < now.year ||
        (_month.year == now.year && _month.month < now.month);
    return SelayaCard(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: () => _shift(-1),
                  icon: Icon(Icons.chevron_left_rounded, color: c.gold)),
              Expanded(
                child: Text('${_mTr[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                  onPressed: canNext ? () => _shift(1) : null,
                  icon: Icon(Icons.chevron_right_rounded,
                      color: canNext ? c.gold : c.textTertiary)),
            ],
          ),
          Row(
            children: [
              for (final w in const ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'])
                Expanded(
                  child: Text(w,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: c.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const Gap.xs(),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (var i = 1; i < firstWeekday; i++) const SizedBox(),
              for (var dnum = 1; dnum <= daysInMonth; dnum++)
                _cell(dnum, now, c),
            ],
          ),
          const Gap.sm(),
          Text('Bir güne dokunarak o günü görebilir/düzenleyebilirsin.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textTertiary)),
        ],
      ),
    );
  }

  Widget _cell(int dnum, DateTime now, dynamic c) {
    final day = DateTime(_month.year, _month.month, dnum);
    final isFuture = day.isAfter(DateTime(now.year, now.month, now.day));
    final count = isFuture ? 0 : widget.marksOf(day).length;
    final ratio = widget.prayers.isEmpty ? 0.0 : count / widget.prayers.length;
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    return GestureDetector(
      onTap: isFuture ? null : () => _showDay(day),
      child: Container(
        decoration: BoxDecoration(
          color: ratio > 0
              ? c.gold.withValues(alpha: 0.15 + ratio * 0.55)
              : c.surfaceAlt,
          borderRadius: BorderRadius.circular(7),
          border: isToday ? Border.all(color: c.gold, width: 1.6) : null,
        ),
        child: Center(
          child: Text('$dnum',
              style: TextStyle(
                  color: isFuture
                      ? c.textTertiary
                      : (ratio > 0.5 ? const Color(0xFF1A1203) : c.textSecondary),
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12)),
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final DateTime day;
  final String lang;
  final Set<String> marks;
  final bool isToday;
  final bool excluded;
  final void Function(String) onToggle;
  const _DayRow({
    required this.day,
    required this.lang,
    required this.marks,
    required this.isToday,
    required this.excluded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text('${day.day}',
                    style: TextStyle(
                        color: isToday ? c.gold : c.textSecondary,
                        fontWeight: FontWeight.w700)),
                Text(formatWeekday(day, lang).substring(0, 2),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
          for (final p in _prayers)
            Expanded(
              child: GestureDetector(
                onTap: excluded ? null : () => onToggle(p),
                child: Container(
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: excluded
                        ? c.surfaceAlt.withValues(alpha: 0.4)
                        : (marks.contains(p)
                            ? c.success.withValues(alpha: 0.85)
                            : c.surface),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(
                    excluded
                        ? AppIcons.moon
                        : (marks.contains(p) ? AppIcons.check : null),
                    size: excluded ? 12 : 16,
                    color: excluded ? c.textTertiary : Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
