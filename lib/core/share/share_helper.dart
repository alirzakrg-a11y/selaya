import 'dart:math';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content_providers.dart';
import '../models/content.dart';
import '../services/gallery_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/verse_share_card.dart';

/// Captures a [RepaintBoundary] (keyed by [boundaryKey]) and shares it via the
/// system sheet. [beforeShare] runs right before the share call (used to pop a
/// bottom sheet first, so iOS presents from the root).
Future<void> shareBoundaryAsImage(
  BuildContext context,
  GlobalKey boundaryKey, {
  required String shareText,
  VoidCallback? beforeShare,
  ShareTarget target = ShareTarget.system,
}) async {
  const share = ShareService();
  // iPad/iOS popover anchor — read before any await so the context is still valid.
  final box = context.findRenderObject() as RenderBox?;
  final origin = (box != null && box.hasSize)
      ? box.localToGlobal(Offset.zero) & box.size
      : null;

  await Future<void>.delayed(const Duration(milliseconds: 60));
  final path = await share.captureBoundary(boundaryKey);
  if (path == null) return;

  beforeShare?.call();
  await share.shareImageFile(path, text: shareText, target: target, origin: origin);
}

/// Opens a sheet previewing a branded verse/hadith card and shares it as an
/// image — directly to WhatsApp / Instagram / Facebook, or via the system sheet.
Future<void> showVerseShareSheet(
  BuildContext context, {
  String? arabic,
  required String text,
  required String reference,
  String? label,
  String? backgroundImage,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareSheet(
      arabic: arabic,
      text: text,
      reference: reference,
      label: label,
      backgroundImage: backgroundImage,
    ),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  final String? arabic;
  final String text;
  final String reference;
  final String? label;
  final String? backgroundImage;
  const _ShareSheet(
      {this.arabic,
      required this.text,
      required this.reference,
      this.label,
      this.backgroundImage});

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _shareKey = GlobalKey();
  bool _busy = false;
  // Arka plan seçimi sheet açıkken sabit kalsın diye sabit tohum.
  final _seed = Random().nextInt(1 << 20);

  String get _shareText =>
      '${widget.text}\n\n— ${widget.reference}\n\nSELAYA · Namaz Vakitlerinden Fazlası';

  Future<void> _doShare(ShareTarget target) async {
    if (_busy) return;
    setState(() => _busy = true);
    const share = ShareService();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final path = await share.captureBoundary(_shareKey);
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    final text = _shareText;
    // Close the sheet first so iOS presents the share UI from the root.
    if (mounted) Navigator.of(context).pop();
    if (path != null) {
      await share.shareImageFile(path,
          text: text, target: target, origin: origin);
    }
  }

  /// Kartı PNG olarak galeriye indir.
  Future<void> _doDownload() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    const share = ShareService();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final path = await share.captureBoundary(_shareKey);
    var ok = false;
    if (path != null) ok = await const GalleryService().saveImageFile(path);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
        content:
            Text(ok ? 'wallpapers.saved'.tr() : 'wallpapers.saveError'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final w = MediaQuery.sizeOf(context).width;
    // Slightly smaller card so it never crowds the targets row on short screens.
    final cardW = (w * 0.56).clamp(180.0, 260.0);
    // Arka plan: çağıran vermediyse PANEL duvar kâğıtlarından rastgele biri
    // (gömülü görsel yalnız panel boş/offline ise VerseShareCard'ın yedeği).
    var bg = widget.backgroundImage;
    if (bg == null || bg.isEmpty) {
      final wps = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];
      if (wps.isNotEmpty) bg = wps[_seed % wps.length].image;
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
          MediaQuery.viewPaddingOf(context).bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          const Gap.lg(),
          // preview card (this is what gets captured)
          ClipRRect(
            borderRadius: AppRadius.rXl,
            child: SizedBox(
              width: cardW,
              height: cardW * 16 / 9,
              child: RepaintBoundary(
                key: _shareKey,
                child: VerseShareCard(
                  arabic: widget.arabic,
                  text: widget.text,
                  reference: widget.reference,
                  label: widget.label,
                  backgroundImage: bg,
                ),
              ),
            ),
          ),
          const Gap.lg(),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.gold)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _doDownload,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text('common.download'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.gold,
                      side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const Gap.md(),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _doShare(ShareTarget.system),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text('common.share'.tr()),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.gold,
                      foregroundColor: const Color(0xFF1A1203),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A row of quick-share targets (WhatsApp / Instagram / Facebook / Other),
/// reused by every share surface so behaviour & styling stay identical.
class ShareTargetsRow extends StatelessWidget {
  final ValueChanged<ShareTarget> onTap;
  const ShareTargetsRow({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ShareTargetButton(
          label: 'WhatsApp',
          icon: Icons.chat_rounded,
          color: const Color(0xFF25D366),
          onTap: () => onTap(ShareTarget.whatsapp),
        ),
        _ShareTargetButton(
          label: 'Instagram',
          icon: Icons.camera_alt_rounded,
          color: const Color(0xFFE1306C),
          onTap: () => onTap(ShareTarget.instagram),
        ),
        _ShareTargetButton(
          label: 'Facebook',
          icon: Icons.facebook_rounded,
          color: const Color(0xFF1877F2),
          onTap: () => onTap(ShareTarget.facebook),
        ),
        _ShareTargetButton(
          label: 'common.more'.tr(),
          icon: Icons.ios_share_rounded,
          color: context.colors.gold,
          onTap: () => onTap(ShareTarget.system),
        ),
      ],
    );
  }
}

class _ShareTargetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ShareTargetButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
