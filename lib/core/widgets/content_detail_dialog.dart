import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../share/share_helper.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Tek bir içerik öğesi (ayet/hadis/dua/esma…) — popup için.
class ContentDetailItem {
  final String title; // üst başlık (esma latin adı vb.) — opsiyonel
  final String arabic; // Arapça (RTL)
  final String transliteration; // okunuş — opsiyonel (italik)
  final String text; // meal/anlam
  final String reference; // kaynak/sıra
  final String shareLabel; // paylaşım etiketi
  final String? shareBg; // paylaşım kartı arka planı — opsiyonel
  final void Function(BuildContext ctx)? onAction; // opsiyonel aksiyon (ör. Zikir Çek)
  final String actionLabel;
  final IconData? actionIcon;
  const ContentDetailItem({
    this.title = '',
    this.arabic = '',
    this.transliteration = '',
    this.text = '',
    this.reference = '',
    this.shareLabel = '',
    this.shareBg,
    this.onAction,
    this.actionLabel = '',
    this.actionIcon,
  });
}

/// Dua'daki popup mantığının GENEL hâli — Ayetler/Hadisler/Esma vb. için.
/// Dokununca ortada büyük açılır; ◀ ▶ oklarla (veya kaydırarak) gezilir + paylaş.
/// [onReachEnd]/[onReachStart]: son/ilk öğeden İLERİ gidilmek istenince çağrılır
/// (ör. Kur'an'da sonraki/önceki sureye geçiş) — verilirse uçlardaki ok da açık kalır.
void showContentDetail(BuildContext context, List<ContentDetailItem> items,
    int index,
    {String headerTitle = '',
    void Function(BuildContext ctx)? onReachEnd,
    void Function(BuildContext ctx)? onReachStart}) {
  if (items.isEmpty) return;
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.82),
    builder: (_) => _ContentDetailDialog(
        items: items,
        initial: index,
        headerTitle: headerTitle,
        onReachEnd: onReachEnd,
        onReachStart: onReachStart),
  );
}

class _ContentDetailDialog extends StatefulWidget {
  final List<ContentDetailItem> items;
  final int initial;
  final String headerTitle;
  final void Function(BuildContext ctx)? onReachEnd;
  final void Function(BuildContext ctx)? onReachStart;
  const _ContentDetailDialog(
      {required this.items,
      required this.initial,
      required this.headerTitle,
      this.onReachEnd,
      this.onReachStart});
  @override
  State<_ContentDetailDialog> createState() => _ContentDetailDialogState();
}

class _ContentDetailDialogState extends State<_ContentDetailDialog> {
  late int _i = widget.initial;

  void _go(int delta) {
    final n = _i + delta;
    if (n >= widget.items.length) {
      widget.onReachEnd?.call(context);
      return;
    }
    if (n < 0) {
      widget.onReachStart?.call(context);
      return;
    }
    setState(() => _i = n);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = widget.items.length;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.xl),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppRadius.rXl,
          border: Border.all(color: c.gold.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.rXl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [c.gold.withValues(alpha: 0.18), c.surfaceAlt]),
                ),
                child: Row(children: [
                  Icon(Icons.auto_stories_rounded, color: c.gold, size: 20),
                  const Gap.sm(),
                  Expanded(
                    child: Text(widget.headerTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: c.gold, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: c.textSecondary),
                    visualDensity: VisualDensity.compact,
                  ),
                ]),
              ),
              // Yükseklik içeriğe göre uyarlanır: kısa metin = küçük popup,
              // uzun metin büyür (en fazla %82 ekran, sonra kaydırılır).
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Sola kaydır → sonraki, sağa kaydır → önceki içerik.
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
                    child: _Page(key: ValueKey(_i), item: widget.items[_i]),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(children: [
                  IconButton(
                    onPressed: (_i > 0 || widget.onReachStart != null)
                        ? () => _go(-1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 30),
                    color: c.gold,
                    disabledColor: c.textTertiary.withValues(alpha: 0.4),
                  ),
                  Expanded(
                    child: Text('${_i + 1} / $total',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: c.textSecondary, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () {
                      final it = widget.items[_i];
                      showVerseShareSheet(context,
                          arabic: it.arabic.isEmpty ? null : it.arabic,
                          text: it.text,
                          reference: it.reference,
                          label: it.shareLabel.isEmpty
                              ? widget.headerTitle
                              : it.shareLabel,
                          backgroundImage: it.shareBg ?? '');
                    },
                    icon: const Icon(Icons.ios_share_rounded, size: 22),
                    color: c.gold,
                    tooltip: 'common.share'.tr(),
                  ),
                  IconButton(
                    onPressed: (_i < total - 1 || widget.onReachEnd != null)
                        ? () => _go(1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 30),
                    color: c.gold,
                    disabledColor: c.textTertiary.withValues(alpha: 0.4),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final ContentDetailItem item;
  const _Page({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.title.isNotEmpty)
            Text(item.title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800)),
          if (item.arabic.isNotEmpty) ...[
            const Gap.lg(),
            Text(item.arabic,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: AppTypography.arabic(
                    fontSize: 28, color: c.textPrimary, height: 1.95)),
          ],
          if (item.transliteration.isNotEmpty) ...[
            const Gap.md(),
            Text(item.transliteration,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.gold,
                    fontStyle: FontStyle.italic,
                    height: 1.5)),
          ],
          if (item.text.isNotEmpty) ...[
            const Gap.md(),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                  color: c.surfaceAlt, borderRadius: AppRadius.rLg),
              child: Text('"${item.text}"',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: c.textSecondary, height: 1.6)),
            ),
          ],
          if (item.reference.isNotEmpty) ...[
            const Gap.md(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded, size: 14, color: c.gold),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(item.reference,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: c.textTertiary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
          if (item.onAction != null) ...[
            const Gap.lg(),
            FilledButton.icon(
              onPressed: () => item.onAction!(context),
              icon: Icon(item.actionIcon ?? Icons.bolt_rounded, size: 18),
              label: Text(item.actionLabel),
              style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.bg,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
