import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/data/manifest_service.dart';
import '../../../core/models/content.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/services/gallery_service.dart';
import '../../../core/services/share_service.dart';
import '../../../core/share/share_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/greeting_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';

const _bgDefaults = [
  'assets/images/inspiration_2.jpg',
  'assets/images/inspiration_1.jpg',
  'assets/images/hero_mosque.jpg',
  'assets/images/stories/story_friday.jpg',
  'assets/images/stories/story_bayram.jpg',
  'assets/images/stories/story_ramadan.jpg',
  'assets/images/stories/story_verse.jpg',
  'assets/images/discover_ramadan.jpg',
];

class GreetingComposerScreen extends ConsumerStatefulWidget {
  const GreetingComposerScreen({super.key});

  @override
  ConsumerState<GreetingComposerScreen> createState() =>
      _GreetingComposerScreenState();
}

class _GreetingComposerScreenState
    extends ConsumerState<GreetingComposerScreen> {
  final _cardKey = GlobalKey();
  final _controller = TextEditingController();
  int _occasion = 0;
  int _bg = 0;
  int _fontIndex = 0;
  double _fontScale = 1.0;
  double _lineHeight = 1.55;
  bool _seeded = false;
  bool _busy = false;

  static const _fontLabels = ['Varsayılan', 'Amiri', 'Zarif', 'El Yazısı', 'Modern'];
  static const _fontFamilies = <String?>[
    null, 'Amiri', 'Playfair Display', 'Dancing Script', 'Sora'
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _doShare(ShareTarget target) async {
    setState(() => _busy = true);
    try {
      await shareBoundaryAsImage(
        context,
        _cardKey,
        shareText: '${_controller.text}\n\nSELAYA · Namaz Vakitlerinden Fazlası',
        target: target,
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kartı galeriye indir (yakala → PNG → galeri).
  Future<void> _downloadCard() async {
    setState(() => _busy = true);
    try {
      final path =
          await ref.read(shareServiceProvider).captureBoundary(_cardKey);
      if (path == null) return;
      final ok = await ref.read(galleryServiceProvider).saveImageFile(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              ok ? 'wallpapers.saved'.tr() : 'wallpapers.saveError'.tr())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final c = context.colors;
    final async = ref.watch(greetingTemplatesProvider);

    return SelayaScaffold(
      title: 'greetings.title'.tr(),
      showBack: true,
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (occasions) {
          if (occasions.isEmpty) return const SelayaEmpty(message: '—');
          if (_occasion >= occasions.length) _occasion = 0;
          final occ = occasions[_occasion];
          if (!_seeded && occ.messages.isNotEmpty) {
            _controller.text = occ.messages.first.text(lang);
            _seeded = true;
          }
          final size = MediaQuery.sizeOf(context);
          // Önizleme kartı 9:16. Yüksekliği ekranın ~%40'ı ile sınırlanır ki
          // diğer kontrolleri (paylaş/indir, hazır mesajlar) ekran dışına itmesin.
          final cardH = (size.width * 0.56 * 16 / 9).clamp(0.0, size.height * 0.4);
          final cardW = cardH * 9 / 16;
          // Arka planlar = DUVAR KÂĞITLARI (panelden yüklediklerin otomatik dahil)
          // + panel tebrik görselleri + paket-içi yedekler. Yeni duvar kâğıdı
          // yükleyince burada da kullanılabilir hâle gelir.
          final wps = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];
          final gExtras = ref.watch(collectionProvider('greeting'));
          final backgrounds = <String>[
            for (final wp in wps)
              if (wp.image.isNotEmpty) wp.image,
            for (final g in gExtras.reversed)
              if (g.url.isNotEmpty) g.url,
            ..._bgDefaults,
          ];
          if (_bg >= backgrounds.length) _bg = 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm,
                AppSpacing.base, AppSpacing.xxxl),
            children: [
              // 1) Konu (occasion) chips
              _Label('greetings.chooseOccasion'.tr()),
              const Gap.sm(),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: occasions.length,
                  separatorBuilder: (_, _) => const Gap.sm(),
                  itemBuilder: (context, i) {
                    final sel = i == _occasion;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _occasion = i;
                        if (occasions[i].messages.isNotEmpty) {
                          _controller.text =
                              occasions[i].messages.first.text(lang);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? c.gold : c.surfaceAlt,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: sel ? c.gold : c.border),
                        ),
                        child: Text(occasions[i].label(lang),
                            style: TextStyle(
                                color: sel
                                    ? const Color(0xFF1A1203)
                                    : c.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    );
                  },
                ),
              ),
              const Gap.md(),
              // 2) Hazır mesajlar — seçilen konuya ait, yatay kaydırmalı.
              _Label('greetings.chooseTemplate'.tr()),
              const Gap.sm(),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: occ.messages.length,
                  separatorBuilder: (_, _) => const Gap.sm(),
                  itemBuilder: (context, i) {
                    final m = occ.messages[i];
                    final sel = _controller.text == m.text(lang);
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _controller.text = m.text(lang)),
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: AppRadius.rLg,
                          border: Border.all(
                              color: sel
                                  ? c.gold.withValues(alpha: 0.7)
                                  : c.border,
                              width: sel ? 1.5 : 1),
                        ),
                        child: Text(m.text(lang),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: c.textSecondary, height: 1.45)),
                      ),
                    );
                  },
                ),
              ),
              const Gap.md(),
              // 3) Düzenlenebilir mesaj
              _Label('greetings.editMessage'.tr()),
              const Gap.sm(),
              TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 2,
                maxLength: 200,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
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
              const Gap.md(),
              // 4) Arka plan seçici
              _Label('greetings.chooseBackground'.tr()),
              const Gap.sm(),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: backgrounds.length,
                  separatorBuilder: (_, _) => const Gap.sm(),
                  itemBuilder: (context, i) {
                    final sel = i == _bg;
                    return GestureDetector(
                      onTap: () => setState(() => _bg = i),
                      child: Container(
                        width: 64,
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.rMd,
                          border: Border.all(
                              color: sel ? c.gold : c.border,
                              width: sel ? 2 : 1),
                        ),
                        child: ClipRRect(
                          borderRadius: AppRadius.rMd,
                          child: AppImage.cdn(backgrounds[i], fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Gap.md(),
              // 5) Yazı tipi (font) seçici
              _Label('Yazı Tipi'),
              const Gap.sm(),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _fontLabels.length,
                  separatorBuilder: (_, _) => const Gap.sm(),
                  itemBuilder: (context, i) {
                    final sel = i == _fontIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _fontIndex = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? c.gold : c.surfaceAlt,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: sel ? c.gold : c.border),
                        ),
                        child: Text(_fontLabels[i],
                            style: TextStyle(
                                color: sel
                                    ? const Color(0xFF1A1203)
                                    : c.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    );
                  },
                ),
              ),
              const Gap.sm(),
              // 6) Yazı boyutu & satır aralığı (line height)
              Row(
                children: [
                  Icon(Icons.text_fields_rounded,
                      size: 18, color: c.textSecondary),
                  Expanded(
                    child: Slider(
                      value: _fontScale,
                      min: 0.6,
                      max: 1.4,
                      divisions: 8,
                      activeColor: c.gold,
                      label: '${(_fontScale * 100).round()}%',
                      onChanged: (v) => setState(() => _fontScale = v),
                    ),
                  ),
                  Text('${(_fontScale * 100).round()}%',
                      style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.format_line_spacing_rounded,
                      size: 18, color: c.textSecondary),
                  Expanded(
                    child: Slider(
                      value: _lineHeight,
                      min: 1.0,
                      max: 2.4,
                      divisions: 14,
                      activeColor: c.gold,
                      label: _lineHeight.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _lineHeight = v),
                    ),
                  ),
                  Text(_lineHeight.toStringAsFixed(1),
                      style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const Gap.md(),
              // 7) Canlı önizleme — ‹ › ile arka planı değiştir (yükseklik sınırlı)
              _Label('greetings.preview'.tr()),
              const Gap.sm(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ArrowBtn(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => setState(() => _bg =
                        (_bg - 1 + backgrounds.length) % backgrounds.length),
                  ),
                  ClipRRect(
                    borderRadius: AppRadius.rXl,
                    child: SizedBox(
                      width: cardW,
                      height: cardH,
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: GreetingCard(
                          message: _controller.text,
                          backgroundImage: backgrounds[_bg],
                          fontFamily: _fontFamilies[_fontIndex],
                          fontScale: _fontScale,
                          lineHeight: _lineHeight,
                        ),
                      ),
                    ),
                  ),
                  _ArrowBtn(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => setState(
                        () => _bg = (_bg + 1) % backgrounds.length),
                  ),
                ],
              ),
              const Gap.sm(),
              // page dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < backgrounds.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _bg ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _bg ? c.gold : c.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
              const Gap.lg(),
              // 8) Paylaş / indir — en altta, son aksiyonlar.
              _busy
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.gold)),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _doShare(ShareTarget.system),
                            icon: const Icon(Icons.ios_share_rounded),
                            label: Text('common.share'.tr()),
                            style: FilledButton.styleFrom(
                              backgroundColor: c.gold,
                              foregroundColor: const Color(0xFF1A1203),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const Gap.sm(),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _downloadCard,
                            icon: const Icon(Icons.download_rounded),
                            label: Text('common.download'.tr()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: c.gold,
                              side: BorderSide(
                                  color: c.gold.withValues(alpha: 0.5)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, color: context.colors.gold, size: 30),
        onPressed: onTap,
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: context.colors.gold)),
      );
}
