import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_scaffold.dart';
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

class _PrayerCard extends StatefulWidget {
  final SpecialPrayer prayer;
  const _PrayerCard({required this.prayer});
  @override
  State<_PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<_PrayerCard> {
  bool _open = false;
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
