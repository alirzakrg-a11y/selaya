import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../data/nafile_reminder_controller.dart';
import '../domain/special_prayers.dart';

/// Nafile / özel namazlar rehberi — 5 vakit dışında kılınan namazlar.
/// Her kart dokununca açılır; içerik Diyanet-doğrulamalıdır. Ana akım dışı
/// (ör. Teveccüh) uyarıyla işaretlidir.
class SpecialPrayersScreen extends StatelessWidget {
  const SpecialPrayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    return SelayaScaffold(
      title: tr ? 'Nafile Namazlar' : 'Voluntary Prayers',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xxxl),
        children: [
          _IntroNote(tr: tr),
          const Gap.md(),
          for (final p in specialPrayers) _PrayerCard(prayer: p),
        ],
      ),
    );
  }
}

class _IntroNote extends StatelessWidget {
  final bool tr;
  const _IntroNote({required this.tr});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, color: c.gold, size: 20),
          const Gap.md(),
          Expanded(
            child: Text(
              tr
                  ? '5 vakit farz namaz dışında kılınan nafile namazlar. İçerik Diyanet İlmihali esas alınarak hazırlanmıştır.'
                  : 'Voluntary prayers beyond the five daily obligatory prayers. Content based on the Diyanet catechism.',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// Hatırlatıcı OLMAYAN nafileler: olay-bazlı (tutulma/yağmur) + ana akım dışı
// (teveccüh) — bunlarda çan gösterilmez.
const _noRemind = {'kusuf', 'istiska', 'teveccuh'};

class _PrayerCard extends ConsumerStatefulWidget {
  final SpecialPrayer prayer;
  const _PrayerCard({required this.prayer});
  @override
  ConsumerState<_PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends ConsumerState<_PrayerCard> {
  bool _open = false;

  /// Çan → hatırlatma kur/değiştir/kaldır (günlük tekrarlayan bildirim).
  Future<void> _reminderTap() async {
    final ctrl = ref.read(nafileReminderProvider.notifier);
    final existing = ctrl.timeFor(widget.prayer.key);
    if (existing != null) {
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Saati değiştir'),
                onTap: () => Navigator.pop(context, 'change'),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_rounded),
                title: const Text('Hatırlatmayı kaldır'),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      );
      if (action == 'clear') {
        await ctrl.clearReminder(widget.prayer.key);
        return;
      }
      if (action != 'change') return;
    }
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: existing ?? const TimeOfDay(hour: 5, minute: 0),
    );
    if (t != null) await ctrl.setReminder(widget.prayer, t);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = context.langCode;
    final tr = l == 'tr';
    final p = widget.prayer;
    final warn = p.warningTr.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: AppRadius.rLg,
          border: Border.all(
              color: warn ? c.gold.withValues(alpha: 0.40) : c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(p.icon, color: c.gold, size: 24),
                    const Gap.md(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p.name(l),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                              ),
                              if (!p.mainstream) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.warning_amber_rounded,
                                    size: 15, color: c.gold),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.rakats,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: c.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (!_noRemind.contains(p.key))
                      _ReminderBell(
                        time: ref.watch(
                            nafileReminderProvider.select((m) => m[p.key])),
                        onTap: _reminderTap,
                      ),
                    Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: c.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (warn) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: c.gold.withValues(alpha: 0.10),
                          borderRadius: AppRadius.rMd,
                          border:
                              Border.all(color: c.gold.withValues(alpha: 0.30)),
                        ),
                        child: Text(
                          p.warningTr,
                          style: TextStyle(
                              color: c.textPrimary, fontSize: 12.5, height: 1.45),
                        ),
                      ),
                      const Gap.sm(),
                    ],
                    _field(c, tr ? 'Vakti' : 'When', p.when(l)),
                    _field(c, tr ? 'Nasıl kılınır' : 'How', p.how(l)),
                    _field(c, tr ? 'Niyet' : 'Intention', p.niyetTr),
                    _field(c, tr ? 'Okunacaklar' : 'Recitation', p.reciteTr),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(SelayaColors c, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
                color: c.gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Nafile kartındaki hatırlatma çanı — kuruluysa altın çan + saat, değilse boş çan.
class _ReminderBell extends StatelessWidget {
  final String? time; // "HH:mm" veya null
  final VoidCallback onTap;
  const _ReminderBell({required this.time, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = time != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              size: 20,
              color: on ? c.gold : c.textTertiary,
            ),
            if (on) ...[
              const SizedBox(width: 3),
              Text(time!,
                  style: TextStyle(
                      color: c.gold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }
}
