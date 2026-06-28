import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../domain/guide.dart';

/// Reusable illustrated how-to guide screen (#16 Abdest / #17 Namaz). Renders an
/// intro banner, numbered step cards (each with a placeholder image area the
/// user fills later), and labelled bullet sections. Large text + spacing for
/// senior readability.
class GuideScreen extends StatelessWidget {
  final Guide guide;
  const GuideScreen({super.key, required this.guide});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.langCode;
    final steps = guide.steps; // Adımlar + görseller paket-içi (bundled).
    return SelayaScaffold(
      title: guide.title(lang),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl),
        children: [
          // Intro banner.
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.gold.withValues(alpha: 0.20), c.surfaceAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.rXl,
              border: Border.all(color: c.gold.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.gold.withValues(alpha: 0.16),
                  ),
                  child: Icon(guide.icon, color: c.gold, size: 26),
                ),
                const Gap.md(),
                Expanded(
                  child: Text(guide.intro(lang),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: c.textSecondary, height: 1.5)),
                ),
              ],
            ),
          ),
          const Gap.lg(),
          Text('guide.steps'.tr(),
              style: Theme.of(context).textTheme.titleLarge),
          const Gap.sm(),
          // Resimli rehberler (abdest/namaz) → ALT ALTA yatay kartlar (sol görsel
          // + numara, sağ başlık + kısa açıklama). Karta dokununca büyük popup
          // açılır; oklarla / kaydırarak tüm aşamalarda gezilir. Resimsiz
          // rehberler tek sütun (eski dikey kart) olarak kalır.
          // TÜM rehberlerde (görselli veya görselsiz) adımlar yatay kart →
          // dokun → büyük popup (oklarla/kaydırarak gez). Görselsiz adımda
          // (gusül, teyemmüm, mest, sargı) görsel yerine ikon görünür.
          for (var i = 0; i < steps.length; i++) ...[
            _StepRow(
              n: i + 1,
              step: steps[i],
              lang: lang,
              onTap: () => _openStepViewer(context, steps, i, lang),
            ),
            const Gap.md(),
          ],
          const Gap.sm(),
          for (final s in guide.sections) ...[
            _SectionCard(section: s, lang: lang),
            const Gap.md(),
          ],
          if (guide.source(lang).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_outlined, size: 15, color: c.textTertiary),
                  const Gap.sm(),
                  Expanded(
                    child: Text(guide.source(lang),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textTertiary, fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Yeni düzen: yatay adım kartı — sol görsel (numara rozeti) + sağ başlık &
/// kısa açıklama. Dokununca büyük popup (oklarla gezinme) açılır.
class _StepRow extends StatelessWidget {
  final int n;
  final GuideStep step;
  final String lang;
  final VoidCallback onTap;
  const _StepRow(
      {required this.n,
      required this.step,
      required this.lang,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.rMd,
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: step.image != null
                      ? AppImage.cdn(step.image!, fit: BoxFit.cover)
                      : Container(
                          color: c.surfaceAlt,
                          alignment: Alignment.center,
                          child: Icon(step.icon, color: c.gold, size: 34)),
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.bg.withValues(alpha: 0.75),
                    border: Border.all(color: c.gold.withValues(alpha: 0.5)),
                  ),
                  child: Text('$n',
                      style: TextStyle(
                          color: c.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
              ),
            ],
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(step.title(lang),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Gap.xs(),
                Text(step.body(lang),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.textSecondary, height: 1.4)),
              ],
            ),
          ),
          const Gap.xs(),
          Icon(Icons.zoom_out_map_rounded, color: c.textTertiary, size: 18),
        ],
      ),
    );
  }
}

/// Adımı büyük göster (kapak görseli + başlık + tam açıklama); oklar veya
/// kaydırma ile tüm aşamalar arasında gezilir.
void _openStepViewer(
    BuildContext context, List<GuideStep> steps, int index, String lang) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.86),
    builder: (_) => _StepViewer(steps: steps, initial: index, lang: lang),
  );
}

class _StepViewer extends StatefulWidget {
  final List<GuideStep> steps;
  final int initial;
  final String lang;
  const _StepViewer(
      {required this.steps, required this.initial, required this.lang});
  @override
  State<_StepViewer> createState() => _StepViewerState();
}

class _StepViewerState extends State<_StepViewer> {
  late int _i = widget.initial;

  void _go(int delta) {
    final n = (_i + delta).clamp(0, widget.steps.length - 1);
    if (n != _i) setState(() => _i = n);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final steps = widget.steps;
    final last = steps.length - 1;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Yükseklik içeriğe göre uyarlanır (kısa adım = küçük popup); sola/sağa
          // kaydır veya alttaki oklarla tüm aşamalar arasında gez.
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -250) {
                  _go(1);
                } else if (v > 250) {
                  _go(-1);
                }
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(_i),
                  decoration: BoxDecoration(
                      color: c.surface, borderRadius: AppRadius.rXl),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: _StepPage(
                        step: steps[_i], n: _i + 1, lang: widget.lang),
                  ),
                ),
              ),
            ),
          ),
          const Gap.md(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NavBtn(
                  icon: Icons.chevron_left_rounded,
                  onTap: _i > 0 ? () => _go(-1) : null),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                    color: c.surface, borderRadius: BorderRadius.circular(99)),
                child: Text('${_i + 1} / ${steps.length}',
                    style: TextStyle(
                        color: c.textPrimary, fontWeight: FontWeight.w700)),
              ),
              _NavBtn(
                  icon: Icons.chevron_right_rounded,
                  onTap: _i < last ? () => _go(1) : null),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tek adım sayfası — kapak görseli (varsa) + numara + başlık + tam açıklama.
class _StepPage extends StatelessWidget {
  final GuideStep step;
  final int n;
  final String lang;
  const _StepPage(
      {required this.step, required this.n, required this.lang});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (step.image != null)
          AspectRatio(
            aspectRatio: 1,
            child: AppImage.cdn(step.image!, fit: BoxFit.contain),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.gold.withValues(alpha: 0.16),
                    ),
                    child: Text('$n',
                        style: TextStyle(
                            color: c.gold, fontWeight: FontWeight.w800)),
                  ),
                  const Gap.md(),
                  Expanded(
                    child: Text(step.title(lang),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const Gap.md(),
              Text(step.body(lang),
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: c.textSecondary, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = onTap != null;
    return Material(
      color: on ? c.gold : c.surface.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon,
              color: on ? c.onGold : c.textTertiary, size: 28),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final GuideSection section;
  final String lang;
  const _SectionCard({required this.section, required this.lang});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, color: c.gold, size: 22),
              const Gap.sm(),
              Expanded(
                child: Text(section.title(lang),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const Gap.sm(),
          for (final item in section.items(lang))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: c.gold, shape: BoxShape.circle),
                    ),
                  ),
                  const Gap.sm(),
                  Expanded(
                    child: Text(item,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: c.textSecondary, height: 1.45)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
