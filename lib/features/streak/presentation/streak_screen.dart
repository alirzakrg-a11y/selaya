import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_scaffold.dart';

class IbadetStats {
  final int streak; // güncel ardışık tam-gün (5 vakit) serisi
  final int longest; // en uzun seri
  final int totalPrayers; // toplam kılınan vakit
  final int completeDays; // 5 vakit tamamlanan gün sayısı
  final int fastDays; // tutulan oruç günü
  final int dhikrTotal; // toplam zikir
  final int todayCount; // bugün kılınan vakit (0-5)
  final List<bool> last7; // son 7 günün tam-gün durumu (eskiden bugüne)
  const IbadetStats(
    this.streak,
    this.longest,
    this.totalPrayers,
    this.completeDays,
    this.fastDays,
    this.dhikrTotal,
    this.todayCount,
    this.last7,
  );
}

/// İbadet takibinin prefs verisinden seri + toplam + rozet istatistiklerini
/// hesaplar (tracking_YYYY-MM-DD = kılınan vakitler, fasting_*, dhikr_total_*).
final ibadetStatsProvider = Provider<IbadetStats>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final keys = prefs.getKeys();
  final dayRe = RegExp(r'^tracking_(\d{4}-\d{2}-\d{2})$');
  final complete = <DateTime>{};
  var total = 0;
  for (final k in keys) {
    final m = dayRe.firstMatch(k);
    if (m == null) continue;
    final cnt = (prefs.getStringList(k) ?? const []).length;
    total += cnt;
    if (cnt >= 5) {
      final d = DateTime.tryParse(m.group(1)!);
      if (d != null) complete.add(DateTime(d.year, d.month, d.day));
    }
  }
  // Güncel seri: bugünden (veya bugün eksikse dünden) geriye ardışık tam günler.
  final t = DateTime.now();
  var day = DateTime(t.year, t.month, t.day);
  if (!complete.contains(day)) day = day.subtract(const Duration(days: 1));
  var streak = 0;
  while (complete.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  // En uzun seri
  final sorted = complete.toList()..sort();
  var longest = 0, run = 0;
  DateTime? prev;
  for (final d in sorted) {
    run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
    if (run > longest) longest = run;
    prev = d;
  }
  var fast = 0;
  var dhikr = 0;
  for (final k in keys) {
    if (k.startsWith('fasting_')) {
      if ((prefs.getString(k) ?? '').startsWith('fast')) fast++;
    } else if (k.startsWith('dhikr_total_')) {
      dhikr += prefs.getInt(k) ?? 0;
    }
  }
  // Bugün kılınan vakit + son 7 günün tam-gün durumu (şerit için).
  final today = DateTime(t.year, t.month, t.day);
  final todayCount = (prefs.getStringList(
              'tracking_${today.toIso8601String().substring(0, 10)}') ??
          const [])
      .length;
  final last7 = <bool>[
    for (var i = 6; i >= 0; i--)
      complete.contains(today.subtract(Duration(days: i)))
  ];
  return IbadetStats(
      streak, longest, total, complete.length, fast, dhikr, todayCount, last7);
});

class _Badge {
  final IconData icon;
  final String name;
  final String desc;
  final bool earned;
  const _Badge(this.icon, this.name, this.desc, this.earned);
}

/// İbadet Serisi & Rozetler — namaz takibinden güncel seri + toplamlar +
/// kazanılan/kilitli rozetler. Kullanıcıyı düzenli ibadete teşvik eder.
class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = context.langCode == 'tr';
    final c = context.colors;
    final s = ref.watch(ibadetStatsProvider);

    final badges = <_Badge>[
      _Badge(
        Icons.flag_rounded,
        tr ? 'İlk Adım' : 'First Step',
        tr ? 'İlk namaz kaydın' : 'First logged prayer',
        s.totalPrayers >= 1,
      ),
      _Badge(
        Icons.local_fire_department_rounded,
        tr ? '7 Gün Seri' : '7-Day Streak',
        tr ? '7 gün üst üste 5 vakit' : '5 prayers, 7 days straight',
        s.longest >= 7,
      ),
      _Badge(
        Icons.workspace_premium_rounded,
        tr ? 'İstikrar' : 'Consistency',
        tr ? '30 gün üst üste 5 vakit' : '5 prayers, 30 days straight',
        s.longest >= 30,
      ),
      _Badge(
        Icons.mosque_rounded,
        tr ? '100 Namaz' : '100 Prayers',
        tr ? '100 vakit namaz kıl' : 'Pray 100 prayers',
        s.totalPrayers >= 100,
      ),
      _Badge(
        Icons.star_rounded,
        tr ? '500 Namaz' : '500 Prayers',
        tr ? '500 vakit namaz kıl' : 'Pray 500 prayers',
        s.totalPrayers >= 500,
      ),
      _Badge(
        Icons.nightlight_round,
        tr ? 'İlk Oruç' : 'First Fast',
        tr ? 'İlk orucunu tut' : 'Keep your first fast',
        s.fastDays >= 1,
      ),
      _Badge(
        Icons.calendar_month_rounded,
        tr ? 'Oruç Ayı' : 'Month of Fasting',
        tr ? '30 gün oruç tut' : 'Fast 30 days',
        s.fastDays >= 30,
      ),
      _Badge(
        Icons.spoke_rounded,
        tr ? 'Zikir Ehli' : 'Devoted to Dhikr',
        tr ? '1000 zikir çek' : 'Do 1000 dhikr',
        s.dhikrTotal >= 1000,
      ),
    ];
    final earned = badges.where((b) => b.earned).length;

    return SelayaScaffold(
      title: tr ? 'İbadet Serim' : 'My Streak',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.sm,
          AppSpacing.base,
          AppSpacing.xxxl,
        ),
        children: [
          // Seri hero kartı
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.gold.withValues(alpha: 0.25), c.surfaceAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.rXl,
              border: Border.all(color: c.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: c.gold,
                  size: 44,
                ),
                const Gap.xs(),
                Text(
                  '${s.streak}',
                  style: TextStyle(
                    color: c.gold,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  s.streak > 0
                      ? (tr ? 'gün üst üste 5 vakit' : 'days of all 5 prayers')
                      : (tr
                            ? 'Bugün 5 vakti tamamla, seriye başla!'
                            : 'Complete all 5 today to start a streak!'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          const Gap.md(),
          _todayCard(context, tr, s),
          const Gap.md(),
          _weekStrip(context, tr, s),
          const Gap.lg(),
          // İstatistik üçlüsü
          Row(
            children: [
              _stat(
                context,
                '${s.totalPrayers}',
                tr ? 'Toplam Namaz' : 'Total Prayers',
              ),
              const Gap.sm(),
              _stat(
                context,
                '${s.longest}',
                tr ? 'En Uzun Seri' : 'Longest Streak',
              ),
              const Gap.sm(),
              _stat(context, '${s.fastDays}', tr ? 'Oruç Günü' : 'Fast Days'),
            ],
          ),
          const Gap.lg(),
          Row(
            children: [
              Text(
                tr ? 'Rozetler' : 'Badges',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '$earned / ${badges.length}',
                style: TextStyle(color: c.gold, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Gap.sm(),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.55,
            children: [for (final b in badges) _badgeCard(context, b)],
          ),
        ],
      ),
    );
  }

  /// Bugünkü 5 vakit ilerlemesi (bar + mesaj).
  Widget _todayCard(BuildContext context, bool tr, IbadetStats s) {
    final c = context.colors;
    final done = s.todayCount.clamp(0, 5);
    final msg = done >= 5
        ? (tr ? 'Maşallah, bugünü tamamladın!' : 'All done for today, mashallah!')
        : (tr ? '${5 - done} vakit kaldı' : '${5 - done} prayers left');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tr ? 'Bugün' : 'Today',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('$done / 5',
                  style: TextStyle(
                      color: c.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ],
          ),
          const Gap.sm(),
          Row(
            children: [
              for (var i = 0; i < 5; i++) ...[
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: i < done ? c.gold : c.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                if (i < 4) const SizedBox(width: 5),
              ],
            ],
          ),
          const Gap.sm(),
          Text(msg,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }

  /// Son 7 günün tam-gün (5 vakit) durumu — gün gün alev/çizgi.
  Widget _weekStrip(BuildContext context, bool tr, IbadetStats s) {
    final c = context.colors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.sm, bottom: AppSpacing.sm),
            child: Text(tr ? 'Son 7 Gün' : 'Last 7 Days',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _dayCell(
                    context,
                    tr,
                    today.subtract(Duration(days: 6 - i)),
                    i < s.last7.length && s.last7[i],
                    i == 6,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(BuildContext context, bool tr, DateTime date, bool done,
      bool isToday) {
    final c = context.colors;
    const wdTr = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'];
    const wdEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? c.gold.withValues(alpha: 0.18) : c.surface,
            border: Border.all(
              color: isToday
                  ? c.gold
                  : (done ? c.gold.withValues(alpha: 0.4) : c.border),
              width: isToday ? 1.6 : 1,
            ),
          ),
          child: Icon(
            done
                ? Icons.local_fire_department_rounded
                : Icons.remove_rounded,
            size: 16,
            color: done ? c.gold : c.textTertiary,
          ),
        ),
        const Gap.xs(),
        Text((tr ? wdTr : wdEn)[date.weekday - 1],
            style: TextStyle(
                color: isToday ? c.gold : c.textTertiary,
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500)),
      ],
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: AppRadius.rLg,
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: c.gold,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Gap.xxs(),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeCard(BuildContext context, _Badge b) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: b.earned ? c.gold.withValues(alpha: 0.12) : c.surfaceAlt,
        borderRadius: AppRadius.rLg,
        border: Border.all(
          color: b.earned ? c.gold.withValues(alpha: 0.5) : c.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            b.earned ? b.icon : Icons.lock_outline_rounded,
            color: b.earned ? c.gold : c.textTertiary,
            size: 26,
          ),
          const Gap.sm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  b.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: b.earned ? c.gold : c.textSecondary,
                  ),
                ),
                Text(
                  b.desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.textTertiary,
                    height: 1.2,
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
