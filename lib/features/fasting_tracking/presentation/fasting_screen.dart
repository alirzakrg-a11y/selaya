import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../calendar/presentation/widgets/hijri_month_grid.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../womens_mode/data/womens_mode_controller.dart';
import '../data/fasting_controller.dart';
import '../domain/fasting_day.dart';

class FastingScreen extends ConsumerStatefulWidget {
  const FastingScreen({super.key});

  @override
  ConsumerState<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends ConsumerState<FastingScreen> {
  late int _year;
  late int _month;
  late DateTime _selectedDay; // the day whose status + note the card shows
  final _notesCtrl = TextEditingController();

  static String _noteKey(DateTime d) =>
      'fasting_note_${d.toIso8601String().substring(0, 10)}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _selectedDay = DateTime(now.year, now.month, now.day);
    _notesCtrl.text = ref
            .read(sharedPreferencesProvider)
            .getString(_noteKey(_selectedDay)) ??
        '';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Focus a day so its status + note show in the card — lets the user view and
  /// edit notes for ANY day (incl. past ones), not just today.
  void _selectDay(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    setState(() => _selectedDay = day);
    _notesCtrl.text =
        ref.read(sharedPreferencesProvider).getString(_noteKey(day)) ?? '';
  }

  void _saveNote(String value) {
    ref
        .read(sharedPreferencesProvider)
        .setString(_noteKey(_selectedDay), value);
  }

  void _shiftMonth(int delta) {
    setState(() {
      final m = DateTime(_year, _month + delta, 1);
      _year = m.year;
      _month = m.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final c = context.colors;
    final store = ref.watch(fastingStoreProvider);
    final wm = ref.watch(womensModeProvider);
    final offset = ref.watch(hijriOffsetProvider);
    final now = DateTime.now();

    final streak = store.streak(wm);
    final totalFasted = store.totalWith(FastStatus.fasted);
    final kazaOwed = store.totalWith(FastStatus.kaza);
    final monthFasted = store.countInMonth(_year, _month, FastStatus.fasted);

    return SelayaScaffold(
      title: 'fasting.title'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          // streak + stats (sade: düz kart, vurgu altın ikon + büyük sayıda)
          SelayaCard(
            child: Row(
              children: [
                Icon(AppIcons.fire, color: c.gold, size: 34),
                const Gap.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('fasting.dayStreak'.tr(args: ['$streak']),
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('fasting.streak'.tr(),
                          style: TextStyle(color: c.textSecondary)),
                    ],
                  ),
                ),
                Text('$streak',
                    style: AppTypography.countdown(c.gold, fontSize: 36)),
              ],
            ),
          ),
          const Gap.md(),
          Row(
            children: [
              _Stat(label: 'fasting.totalFasted'.tr(), value: '$totalFasted', color: c.success),
              const Gap.sm(),
              _Stat(label: 'fasting.kazaOwed'.tr(), value: '$kazaOwed', color: c.danger),
              const Gap.sm(),
              _Stat(label: 'fasting.thisMonth'.tr(), value: '$monthFasted', color: c.gold),
            ],
          ),
          const Gap.lg(),
          _buildDayCard(store, now),
          const Gap.lg(),
          // month navigation
          Row(
            children: [
              IconButton(
                icon: const Icon(AppIcons.back, size: 18),
                onPressed: () => _shiftMonth(-1),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy', lang).format(DateTime(_year, _month)),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(AppIcons.forward, size: 22),
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
          const Gap.sm(),
          SelayaCard(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: HijriMonthGrid(
              year: _year,
              month: _month,
              lang: lang,
              cellBuilder: (day) => _cell(day, store, wm, offset, now),
            ),
          ),
          const Gap.md(),
          _Legend(),
        ],
      ),
    );
  }

  Widget _buildDayCard(FastingStore store, DateTime now) {
    final c = context.colors;
    final lang = context.langCode;
    final offset = ref.read(hijriOffsetProvider);
    final day = _selectedDay;
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final status = store.statusFor(day);
    return SelayaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.moon, color: c.gold, size: 20),
              const Gap.sm(),
              Expanded(
                child: Text(
                    isToday
                        ? 'fasting.todayQuestion'.tr()
                        : formatGregorian(day, lang),
                    style: Theme.of(context).textTheme.titleSmall),
              ),
            ],
          ),
          const Gap.sm(),
          // Three-way status for the SELECTED day — any day (incl. past) can be
          // set here, and its note below is saved per-day.
          SegmentedButton<FastStatus>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: FastStatus.none,
                  label: Text('fasting.notFasted'.tr())),
              ButtonSegment(
                  value: FastStatus.fasted, label: Text('fasting.fasted'.tr())),
              ButtonSegment(
                  value: FastStatus.kaza, label: Text('fasting.kaza'.tr())),
            ],
            selected: {status},
            // İleri tarih işaretlenemez — sadece bugün ve geçmiş günler.
            onSelectionChanged:
                day.isAfter(DateTime(now.year, now.month, now.day))
                    ? null
                    : (s) {
                        store.setStatus(day, s.first);
                        HapticFeedback.selectionClick();
                        setState(() {});
                      },
          ),
          const Gap.sm(),
          TextField(
            controller: _notesCtrl,
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
            onChanged: _saveNote,
            decoration: InputDecoration(
              hintText: 'fasting.notesHint'.tr(),
              filled: true,
              fillColor: c.surfaceAlt,
              border: OutlineInputBorder(
                  borderRadius: AppRadius.rLg,
                  borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.rLg,
                  borderSide: BorderSide(color: c.border)),
            ),
          ),
          const Gap.sm(),
          Row(
            children: [
              Expanded(
                child: _DateChip(
                    label: 'fasting.gregorian'.tr(),
                    value: formatGregorian(day, lang)),
              ),
              const Gap.sm(),
              Expanded(
                child: _DateChip(
                    label: 'fasting.hijri'.tr(),
                    value: formatHijri(day, lang, offsetDays: offset)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(DateTime day, FastingStore store, WomensMode wm, int offset,
      DateTime now) {
    final c = context.colors;
    final status = store.statusFor(day);
    final excluded = wm.isExcluded(day);
    final hijri = HijriCalendar.fromDate(
        offset == 0 ? day : day.add(Duration(days: offset)));
    final isRamadan = hijri.hMonth == 9;
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final isSelected = day.year == _selectedDay.year &&
        day.month == _selectedDay.month &&
        day.day == _selectedDay.day;

    Color bg = c.surface;
    Color fg = c.textPrimary;
    if (excluded) {
      bg = c.surfaceAlt.withValues(alpha: 0.4);
      fg = c.textTertiary;
    } else if (status == FastStatus.fasted) {
      bg = c.success.withValues(alpha: 0.85);
      fg = Colors.white;
    } else if (status == FastStatus.kaza) {
      bg = c.danger.withValues(alpha: 0.8);
      fg = Colors.white;
    }

    return GestureDetector(
      // Tap selects the day → its status + note load into the card above, so any
      // past day's note can be viewed/edited. Status is set from that card.
      onTap: () => _selectDay(day),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? c.gold
                : isToday
                    ? c.gold.withValues(alpha: 0.7)
                    : (isRamadan ? c.gold.withValues(alpha: 0.45) : c.border),
            width: isSelected ? 2.4 : (isToday ? 1.6 : 1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${day.day}',
                style: TextStyle(
                    color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
            Text('${hijri.hDay}',
                style: TextStyle(
                    color: fg.withValues(alpha: 0.6), fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: SelayaCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700)),
            const Gap.xs(),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: c.textTertiary)),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String value;
  const _DateChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.textTertiary)),
          const SizedBox(height: 2),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget chip(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const Gap.xs(),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.textSecondary)),
          ],
        );
    return Wrap(
      spacing: AppSpacing.base,
      runSpacing: AppSpacing.sm,
      children: [
        chip(c.success.withValues(alpha: 0.85), 'fasting.fasted'.tr()),
        chip(c.danger.withValues(alpha: 0.8), 'fasting.kaza'.tr()),
      ],
    );
  }
}
