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
import '../../auth/data/auth_controller.dart';

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
  final _toCtrl = TextEditingController(); // alıcı (Kime) — karta hitap satırı
  final _fromCtrl = TextEditingController(); // gönderen (Kimden) — imza
  int _occasion = 0;
  int _bg = 0;
  int _fontIndex = 0;
  double _fontScale = 1.0;
  double _lineHeight = 1.55;
  int _colorIndex = 0; // metin rengi
  int _alignIndex = 0; // 0 orta · 1 sol · 2 sağ
  bool _framed = false; // altın çerçeve
  double _overlay = 1.0; // fotoğraf karartması (0.5–1.4)
  bool _seeded = false;
  bool _busy = false;
  int _tool = 0; // Canva araç sekmesi: 0 Mesaj · 1 Arka Plan · 2 Yazı · 3 Kime

  // ── Kart üzerinde DOĞRUDAN dokunma (gerçek Canva hissi) ──
  int _anchorIndex = 0; // hazır konum şablonu (bkz _anchors)
  Offset _textNudge = Offset.zero; // sürükleyerek eklenen ince ayar (normalize)
  double _baseFontScale = 1.0; // pinch başlarken _fontScale'i dondurmak için
  final _msgFocus = FocusNode(); // karta dokununca Mesaj alanına odaklanmak için

  // Hazır konum şablonları: kart içinde mesajın oturduğu Alignment.
  static const _anchors = <Alignment>[
    Alignment.center,
    Alignment(0, -0.72),
    Alignment(0, 0.7),
    Alignment(-0.62, 0.7),
    Alignment(0.62, 0.7),
  ];
  static const _anchorIcons = <IconData>[
    Icons.vertical_align_center_rounded,
    Icons.vertical_align_top_rounded,
    Icons.vertical_align_bottom_rounded,
    Icons.south_west_rounded,
    Icons.south_east_rounded,
  ];

  static const _fontLabels = ['Varsayılan', 'Amiri', 'Zarif', 'El Yazısı', 'Modern'];
  static const _fontFamilies = <String?>[
    null, 'Amiri', 'Playfair Display', 'Dancing Script', 'Sora'
  ];
  // Metin renk paleti: beyaz · altın · krem · koyu (fotoğrafa göre okunur).
  static const _textColors = <Color>[
    Colors.white,
    Color(0xFFE9C15E),
    Color(0xFFF3E9D2),
    Color(0xFF11131C),
  ];
  static const _aligns = <TextAlign>[
    TextAlign.center,
    TextAlign.left,
    TextAlign.right,
  ];

  /// Karta hitap eden son metin: "Sevgili {alıcı}," + mesaj + "— {gönderen}".
  String _composed(String lang) {
    final to = _toCtrl.text.trim();
    final from = _fromCtrl.text.trim();
    final body = _controller.text.trim();
    final buf = StringBuffer();
    if (to.isNotEmpty) buf.write('${'xt.gcDear'.tr()} $to,\n\n');
    buf.write(body);
    if (from.isNotEmpty) buf.write('\n\n— $from');
    return buf.toString();
  }

  // Küçük stil etiketleri için (yeni 10-dil çeviri anahtarı açmamak adına) —
  // TR birincil kullanıcı, diğer diller EN'e düşer.
  String _ll(String tr, String en) => context.langCode == 'tr' ? tr : en;

  String _anchorLabel(int i) => switch (i) {
        0 => _ll('Orta', 'Center'),
        1 => _ll('Üst', 'Top'),
        2 => _ll('Alt', 'Bottom'),
        3 => _ll('Sol Alt', 'Bottom L'),
        _ => _ll('Sağ Alt', 'Bottom R'),
      };

  @override
  void dispose() {
    _controller.dispose();
    _toCtrl.dispose();
    _fromCtrl.dispose();
    _msgFocus.dispose();
    super.dispose();
  }

  Future<void> _doShare(ShareTarget target) async {
    setState(() => _busy = true);
    try {
      await shareBoundaryAsImage(
        context,
        _cardKey,
        shareText:
            '${_composed(context.langCode)}\n\nSELAYA · Namaz Vakitlerinden Fazlası',
        target: target,
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Üstteki "Sıfırla" ikonu: metin/arka plan İÇERİĞİNE dokunmadan, sadece
  /// stil ayarlarını (font/boyut/renk/hizalama/konum/çerçeve/karartma) baştaki
  /// haline döndürür — Canva'daki "reset" hissi.
  void _resetStyle() => setState(() {
        _fontIndex = 0;
        _fontScale = 1.0;
        _lineHeight = 1.55;
        _colorIndex = 0;
        _alignIndex = 0;
        _framed = false;
        _overlay = 1.0;
        _anchorIndex = 0;
        _textNudge = Offset.zero;
        _baseFontScale = 1.0;
      });

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

  /// Kompakt "Kime / Kimden" giriş alanı.
  Widget _nameField(TextEditingController ctrl, String hint, IconData icon) {
    final c = context.colors;
    return TextField(
      controller: ctrl,
      maxLength: 30,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: c.gold),
        isDense: true,
        counterText: '',
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        border: OutlineInputBorder(
            borderRadius: AppRadius.rLg,
            borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.rLg,
            borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.rLg,
            borderSide: BorderSide(color: c.gold, width: 1.4)),
      ),
    );
  }

  /// Canva-tarzı alt araç sekmesi (ikon + etiket; seçiliyse altın).
  Widget _toolTab(int idx, IconData icon, String label) {
    final c = context.colors;
    final sel = _tool == idx;
    return Expanded(
      child: InkWell(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() => _tool = idx);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: sel ? c.gold : Colors.transparent, width: 2.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: sel ? c.gold : c.textTertiary),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? c.gold : c.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final c = context.colors;
    final async = ref.watch(greetingTemplatesProvider);

    return SelayaScaffold(
      title: 'greetings.title'.tr(),
      showBack: true,
      // Canva'daki gibi Paylaş/İndir/Sıfırla üst çubukta ikon — alt kısım
      // tamamen araç/şablon seçimine ayrılır (bkz kullanıcı referans görseli).
      actions: [
        IconButton(
          icon: const Icon(Icons.restart_alt_rounded),
          tooltip: _ll('Stili sıfırla', 'Reset style'),
          onPressed: _busy ? null : _resetStyle,
        ),
        IconButton(
          icon: const Icon(Icons.download_rounded),
          tooltip: 'common.download'.tr(),
          onPressed: _busy ? null : _downloadCard,
        ),
        IconButton(
          icon: const Icon(Icons.ios_share_rounded),
          tooltip: 'common.share'.tr(),
          onPressed: _busy ? null : () => _doShare(ShareTarget.system),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (occasions) {
          if (occasions.isEmpty) {
            return SelayaEmpty(
              icon: Icons.card_giftcard_rounded,
              message: 'common.empty'.tr(),
            );
          }
          if (_occasion >= occasions.length) _occasion = 0;
          final occ = occasions[_occasion];
          if (!_seeded && occ.messages.isNotEmpty) {
            _controller.text = occ.messages.first.text(lang);
            // İmzayı (Kimden) giriş yapan kullanıcının adıyla otomatik doldur.
            final u = ref.read(authControllerProvider).user;
            if (u != null && u.name.trim().isNotEmpty) {
              _fromCtrl.text = u.name.trim();
            }
            _seeded = true;
          }
          final size = MediaQuery.sizeOf(context);
          final wps = ref.watch(wallpapersProvider).value ?? const <Wallpaper>[];
          final gExtras = ref.watch(collectionProvider('greeting'));
          // Arka planlar = DUVAR KÂĞITLARI (panelden yüklediklerin otomatik dahil)
          // + panel tebrik görselleri + paket-içi yedekler.
          final backgrounds = <String>[
            for (final wp in wps)
              if (wp.image.isNotEmpty) wp.image,
            for (final g in gExtras.reversed)
              if (g.url.isNotEmpty) g.url,
            ..._bgDefaults,
          ];
          if (_bg >= backgrounds.length) _bg = 0;
          // Canva düzeni: kart (canvas) EN ÜSTTE sabit; araçlar altta sekmeli
          // panelde. Klavye açılınca canvas küçülür ki düzenleme alanı görünür kalsın.
          final kbOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
          final cardH = (size.width * 0.6 * 16 / 9)
              .clamp(0.0, size.height * (kbOpen ? 0.24 : 0.42));
          final cardW = cardH * 9 / 16;

          return Column(
            children: [
              // ── CANVAS (en üstte, sabit) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                    AppSpacing.sm, AppSpacing.base, AppSpacing.xs),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _ArrowBtn(
                          icon: Icons.chevron_left_rounded,
                          onTap: () => setState(() => _bg =
                              (_bg - 1 + backgrounds.length) %
                                  backgrounds.length),
                        ),
                        Expanded(
                          child: Center(
                            child: ClipRRect(
                              borderRadius: AppRadius.rXl,
                              child: SizedBox(
                                width: cardW,
                                height: cardH,
                                // Gerçek Canva hissi: karta dokunup SÜRÜKLEYEREK
                                // metni konumlandır, İKİ PARMAKLA yakınlaştır/
                                // uzaklaştır, TEK dokunuşla Mesaj alanına atla.
                                // GestureDetector RepaintBoundary'yi SARIYOR (içi
                                // değil) → paylaşım/indirme yakalaması etkilenmez.
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onScaleStart: (_) =>
                                      _baseFontScale = _fontScale,
                                  onScaleUpdate: (d) => setState(() {
                                    _fontScale =
                                        (_baseFontScale * d.scale)
                                            .clamp(0.55, 2.0);
                                    final dx = d.focalPointDelta.dx / cardW;
                                    final dy = d.focalPointDelta.dy / cardH;
                                    _textNudge = Offset(
                                      (_textNudge.dx + dx).clamp(-0.34, 0.34),
                                      (_textNudge.dy + dy).clamp(-0.30, 0.30),
                                    );
                                  }),
                                  onTap: () {
                                    setState(() => _tool = 0);
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        FocusScope.of(context)
                                            .requestFocus(_msgFocus);
                                      }
                                    });
                                  },
                                  child: RepaintBoundary(
                                    key: _cardKey,
                                    child: GreetingCard(
                                      message: _composed(lang),
                                      backgroundImage: backgrounds[_bg],
                                      fontFamily: _fontFamilies[_fontIndex],
                                      fontScale: _fontScale,
                                      lineHeight: _lineHeight,
                                      textColor: _textColors[_colorIndex],
                                      textAlign: _aligns[_alignIndex],
                                      framed: _framed,
                                      overlayStrength: _overlay,
                                      textAnchor: _anchors[_anchorIndex],
                                      textNudge: _textNudge,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _ArrowBtn(
                          icon: Icons.chevron_right_rounded,
                          onTap: () => setState(() =>
                              _bg = (_bg + 1) % backgrounds.length),
                        ),
                      ],
                    ),
                    const Gap.xs(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0;
                            i < backgrounds.length && i < 12;
                            i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs),
                            width: i == _bg ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _bg ? c.gold : c.border,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                      ],
                    ),
                    const Gap.sm(),
                    // ── DÜZEN şeridi: hazır konum şablonları (Canva "template"
                    // seçme hissi) — dokununca metin ANINDA o konuma oturur;
                    // ince ayar için hâlâ karttan sürüklenebilir.
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _anchors.length,
                        separatorBuilder: (_, _) => const Gap.sm(),
                        itemBuilder: (context, i) => _AnchorChip(
                          icon: _anchorIcons[i],
                          label: _anchorLabel(i),
                          selected: i == _anchorIndex,
                          onTap: () => setState(() {
                            _anchorIndex = i;
                            _textNudge = Offset.zero; // her şablon sıfırdan başlar
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── ARAÇ SEKMELERİ (Canva alt çubuğu gibi) ──
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(
                    top: BorderSide(color: c.border),
                    bottom: BorderSide(color: c.border),
                  ),
                ),
                child: Row(
                  children: [
                    _toolTab(0, Icons.chat_bubble_outline_rounded,
                        'xt.gcTabMessage'.tr()),
                    _toolTab(1, Icons.image_outlined,
                        'xt.gcTabBackground'.tr()),
                    _toolTab(2, Icons.text_fields_rounded,
                        'xt.gcTabFont'.tr()),
                    _toolTab(3, Icons.favorite_outline_rounded,
                        'xt.gcTabToFrom'.tr()),
                  ],
                ),
              ),
              // ── SEÇİLİ ARACIN PANELİ (kaydırılır) ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                      AppSpacing.md, AppSpacing.base, AppSpacing.lg),
                  children: switch (_tool) {
                    // 0 — MESAJ: konu + hazır şablon + düzenlenebilir metin
                    0 => [
                        _Label('greetings.chooseOccasion'.tr()),
                        const Gap.sm(),
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: occasions.length,
                            separatorBuilder: (_, _) => const Gap.sm(),
                            itemBuilder: (context, i) => _ChipButton(
                              label: occasions[i].label(lang),
                              selected: i == _occasion,
                              onTap: () => setState(() {
                                _occasion = i;
                                if (occasions[i].messages.isNotEmpty) {
                                  _controller.text =
                                      occasions[i].messages.first.text(lang);
                                }
                              }),
                            ),
                          ),
                        ),
                        const Gap.md(),
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
                                onTap: () => setState(
                                    () => _controller.text = m.text(lang)),
                                child: Container(
                                  width: 220,
                                  padding:
                                      const EdgeInsets.all(AppSpacing.md),
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
                                              color: c.textSecondary,
                                              height: 1.45)),
                                ),
                              );
                            },
                          ),
                        ),
                        const Gap.md(),
                        _Label('greetings.editMessage'.tr()),
                        const Gap.sm(),
                        TextField(
                          controller: _controller,
                          focusNode: _msgFocus,
                          maxLines: 6,
                          minLines: 3,
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
                            focusedBorder: OutlineInputBorder(
                                borderRadius: AppRadius.rLg,
                                borderSide:
                                    BorderSide(color: c.gold, width: 1.4)),
                          ),
                        ),
                      ],
                    // 1 — ARKA PLAN: ızgara (Canva gibi)
                    1 => [
                        _Label('greetings.chooseBackground'.tr()),
                        const Gap.sm(),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 9 / 16,
                          ),
                          itemCount: backgrounds.length,
                          itemBuilder: (context, i) {
                            final sel = i == _bg;
                            return GestureDetector(
                              onTap: () => setState(() => _bg = i),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: AppRadius.rMd,
                                  border: Border.all(
                                      color: sel ? c.gold : c.border,
                                      width: sel ? 2.5 : 1),
                                ),
                                child: ClipRRect(
                                  borderRadius: AppRadius.rMd,
                                  child: AppImage.cdn(backgrounds[i],
                                      fit: BoxFit.cover),
                                ),
                              ),
                            );
                          },
                        ),
                        const Gap.lg(),
                        _Label(_ll('Fotoğraf Karartma', 'Photo Dimming')),
                        Row(
                          children: [
                            Icon(Icons.brightness_6_rounded,
                                size: 18, color: c.textSecondary),
                            Expanded(
                              child: Slider(
                                value: _overlay,
                                min: 0.5,
                                max: 1.4,
                                divisions: 9,
                                activeColor: c.gold,
                                label: '${(_overlay * 100).round()}%',
                                onChanged: (v) =>
                                    setState(() => _overlay = v),
                              ),
                            ),
                            Text('${(_overlay * 100).round()}%',
                                style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const Gap.sm(),
                        Row(
                          children: [
                            Icon(Icons.crop_din_rounded,
                                size: 18, color: c.gold),
                            const Gap.sm(),
                            Expanded(
                              child: Text(_ll('Altın çerçeve', 'Gold frame'),
                                  style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Switch(
                              value: _framed,
                              activeThumbColor: c.gold,
                              onChanged: (v) => setState(() => _framed = v),
                            ),
                          ],
                        ),
                      ],
                    // 2 — YAZI: font + boyut + satır aralığı
                    2 => [
                        _Label('xt.gcFontFamily'.tr()),
                        const Gap.sm(),
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _fontLabels.length,
                            separatorBuilder: (_, _) => const Gap.sm(),
                            itemBuilder: (context, i) => _ChipButton(
                              label: _fontLabels[i],
                              selected: i == _fontIndex,
                              onTap: () => setState(() => _fontIndex = i),
                            ),
                          ),
                        ),
                        const Gap.md(),
                        _Label('xt.gcTextSize'.tr()),
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
                                onChanged: (v) =>
                                    setState(() => _fontScale = v),
                              ),
                            ),
                            Text('${(_fontScale * 100).round()}%',
                                style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        _Label('xt.gcLineSpacing'.tr()),
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
                                onChanged: (v) =>
                                    setState(() => _lineHeight = v),
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
                        _Label(_ll('Metin Rengi', 'Text Color')),
                        const Gap.sm(),
                        Row(
                          children: [
                            for (var i = 0; i < _textColors.length; i++)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _colorIndex = i),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: _textColors[i],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: i == _colorIndex
                                            ? c.gold
                                            : c.border,
                                        width: i == _colorIndex ? 2.5 : 1),
                                  ),
                                  child: i == _colorIndex
                                      ? Icon(Icons.check_rounded,
                                          size: 18,
                                          color: _textColors[i]
                                                      .computeLuminance() >
                                                  0.5
                                              ? Colors.black
                                              : Colors.white)
                                      : null,
                                ),
                              ),
                          ],
                        ),
                        const Gap.md(),
                        _Label(_ll('Hizalama', 'Alignment')),
                        const Gap.sm(),
                        Row(
                          children: [
                            for (var i = 0; i < _aligns.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _alignIndex = i),
                                  child: Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: i == _alignIndex
                                          ? c.gold
                                          : c.surfaceAlt,
                                      borderRadius: AppRadius.rMd,
                                      border: Border.all(
                                          color: i == _alignIndex
                                              ? c.gold
                                              : c.border),
                                    ),
                                    child: Icon(
                                      const [
                                        Icons.format_align_center_rounded,
                                        Icons.format_align_left_rounded,
                                        Icons.format_align_right_rounded,
                                      ][i],
                                      size: 20,
                                      color: i == _alignIndex
                                          ? c.onGold
                                          : c.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    // 3 — KİME / KİMDEN: kişiye hitap
                    _ => [
                        _Label('xt.gcPersonalize'.tr()),
                        const Gap.sm(),
                        Row(
                          children: [
                            Expanded(
                              child: _nameField(
                                  _toCtrl,
                                  'xt.gcToHint'.tr(),
                                  Icons.favorite_outline_rounded),
                            ),
                            const Gap.sm(),
                            Expanded(
                              child: _nameField(
                                  _fromCtrl,
                                  'xt.gcFromHint'.tr(),
                                  Icons.draw_outlined),
                            ),
                          ],
                        ),
                        const Gap.sm(),
                        Text(
                          'xt.gcPersonalizeHint'.tr(),
                          style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ],
                  },
                ),
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

class _ChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? c.gold : c.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? c.gold : c.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? c.onGold : c.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}

/// Düzen (konum) şablonu çipi — ikon + küçük etiket, seçiliyse altın.
class _AnchorChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AnchorChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.gold : c.surfaceAlt,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: selected ? c.gold : c.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? c.onGold : c.textSecondary),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? c.onGold : c.textTertiary)),
          ],
        ),
      ),
    );
  }
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
