import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/mini_player_chrome.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../hatim/data/hatim_controller.dart';
import '../data/mushaf_meta.dart';
import '../data/quran_audio_controller.dart';
import '../data/quran_tracks.dart';
import 'quran_caching_badge.dart';

/// 📖 Sayfadaki ayetlerin MEALİ (madde 4) — sayfa→ayet eşlemesinden (mushaf_meta)
/// + offline verses_NNN.json'dan. Her öğe (sure, Verse). Mushaf meal paneli kullanır.
/// Tüm veri yerel (çevrimdışı çalışır); sayfa görselinin aksine ağ gerektirmez.
final mushafPageVersesProvider =
    FutureProvider.family<List<({int surah, Verse verse})>, int>((
      ref,
      page,
    ) async {
      final surahs = await ref.watch(surahsProvider.future);
      int ayahCountOf(int s) => surahs
          .firstWhere((x) => x.number == s, orElse: () => surahs.first)
          .ayahCount;
      final segments = versesOnPage(page, ayahCountOf);
      final out = <({int surah, Verse verse})>[];
      for (final seg in segments) {
        final verses = await ref.watch(versesProvider(seg.surah).future);
        for (var a = seg.start; a <= seg.end && a <= verses.length; a++) {
          out.add((surah: seg.surah, verse: verses[a - 1]));
        }
      }
      return out;
    });

/// 📖 MUSHAF MODU — gerçek Medine mushafı, sayfa sayfa (604 sayfa).
/// Kart görünümünün yanındaki ikinci okuma tarzı: sağdan sola sayfa çevrilir
/// (gerçek mushaf gibi), iki parmakla yakınlaştırılır; altta cüz + sayfa
/// göstergesi. Kalınan sayfa hatırlanır.
class MushafScreen extends ConsumerStatefulWidget {
  /// Açılış sayfası (1-604). Verilmezse kalınan sayfadan devam eder.
  final int? initialPage;
  const MushafScreen({super.key, this.initialPage});

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen>
    with WidgetsBindingObserver {
  late int _page =
      (widget.initialPage ??
              ref
                  .read(sharedPreferencesProvider)
                  .getInt(PrefKeys.mushafLastPage) ??
              1)
          .clamp(1, mushafPageCount);
  late final PageController _pc = PageController(initialPage: _page - 1);

  // 📖 HATİM otomatik sayım: sayfada en az 3 sn geçirip İLERİ gidince o sayfa
  // okundu sayılır (geri gidiş sayılmaz; gün-içi dedup controller'da).
  DateTime _pageEnteredAt = DateTime.now();
  late final HatimController _hatim = ref.read(
    hatimControllerProvider.notifier,
  );

  /// Mevcut sayfada ≥3 sn geçildiyse onu okundu işle (dispose + arka plan için
  /// — yoksa son okunan sayfa ve 604. sayfa asla sayılmazdı). recordPage gün-içi
  /// dedup yaptığından çift sayım kendiliğinden engellenir.
  void _countCurrentIfDwelt() {
    if (DateTime.now().difference(_pageEnteredAt).inSeconds >= 3) {
      _hatim.recordPage(_page);
    }
  }

  /// Zoom durumu — YALNIZCA görünen sayfanın InteractiveViewer'ına bağlanır.
  /// (Önceki sürümde komşu sayfalar da aynı controller'ı paylaşıyordu ve
  /// birbirinin değerini eziyordu → çift dokunuş "tutmuyordu".)
  final _zoom = TransformationController();
  TapDownDetails? _doubleTapAt;

  /// Madde 4: alt meal paneli açık mı (çeviri toggle ile aç/kapa).
  bool _showMeal = false;

  void _onDoubleTap() {
    // Zaten yakınsa → %100'e dön; değilse dokunulan noktaya yakınlaş.
    if (_zoom.value.getMaxScaleOnAxis() > 1.05) {
      setState(() => _zoom.value = Matrix4.identity());
      return;
    }
    const s = 2.4;
    final p = _doubleTapAt?.localPosition ?? const Offset(200, 300);
    setState(() {
      _zoom.value = Matrix4.identity()
        ..translateByDouble(-p.dx * (s - 1), -p.dy * (s - 1), 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precacheAround(_page);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Arka plana giderken mevcut sayfada yeterince kalındıysa say.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _countCurrentIfDwelt();
    }
  }

  void _onPage(int index) {
    final newPage = index + 1;
    // Ayrılmakta olduğumuz sayfa (_page) ileri yönde ve ≥3 sn ise okundu say.
    if (newPage > _page &&
        DateTime.now().difference(_pageEnteredAt).inSeconds >= 3) {
      _hatim.recordPage(_page);
    }
    _pageEnteredAt = DateTime.now();
    setState(() => _page = newPage);
    // Başka SUREYE geçince çalan sesi durdur (kullanıcı 2026-06-15: "Fâtiha
    // dinlerken başka sureye geçince sussun"). Aynı sure içinde sayfa çevirmek
    // sesi kesmez (Bakara gibi çok sayfalı sureler kesintisiz çalar).
    final audio = ref.read(quranAudioControllerProvider);
    if (audio.surahNumber != null &&
        audio.surahNumber != surahForPage(newPage)) {
      ref.read(quranAudioControllerProvider.notifier).stop();
    }
    // Yeni sayfa daima %100'de açılır (zoom önceki sayfada kalmasın).
    _zoom.value = Matrix4.identity();
    ref.read(sharedPreferencesProvider).setInt(PrefKeys.mushafLastPage, _page);
    _precacheAround(_page);
  }

  /// Komşu sayfaları önden indir → çevirince beklemeden açılır ("yavaş
  /// açılıyor" şikâyetinin ilacı; bir kez inen sayfa kalıcı önbellekte).
  void _precacheAround(int page) {
    for (final p in [page + 1, page - 1, page + 2]) {
      if (p >= 1 && p <= mushafPageCount) {
        precacheImage(CachedNetworkImageProvider(mushafPageUrl(p)), context);
      }
    }
  }

  /// 🧭 Hızlı seçim: Sureler (aramalı) + Cüzler — dokun, sayfasına atla.
  void _openPicker() {
    final c = context.colors;
    final lang = context.langCode;
    final surahs = ref.read(surahsProvider).value ?? const <Surah>[];
    var query = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final list = query.isEmpty
              ? surahs
              : surahs
                    .where(
                      (s) =>
                          s.name(lang).toLowerCase().contains(query) ||
                          s.transliteration.toLowerCase().contains(query) ||
                          s.number.toString() == query,
                    )
                    .toList();
          return SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.72,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: c.gold,
                    unselectedLabelColor: c.textTertiary,
                    indicatorColor: c.gold,
                    tabs: [
                      Tab(text: 'xt.muTabSurahs'.tr()),
                      Tab(text: 'xt.muTabJuz'.tr()),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                              child: TextField(
                                onChanged: (v) =>
                                    setSheet(() => query = v.toLowerCase()),
                                decoration: InputDecoration(
                                  hintText: 'xt.muSearchSurah'.tr(),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 12,
                                  ),
                                  filled: true,
                                  fillColor: c.surfaceAlt,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: c.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: c.gold,
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: list.length,
                                itemBuilder: (ctx2, i) {
                                  final s = list[i];
                                  final p = pageForSurah(s.number);
                                  final mekki = s.revelation == 'meccan';
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: c.gold.withValues(
                                        alpha: 0.14,
                                      ),
                                      child: Text(
                                        '${s.number}',
                                        style: TextStyle(
                                          color: c.gold,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    title: Text(s.name(lang)),
                                    // Ayrıntı: iniş yeri · ayet sayısı · cüz.
                                    subtitle: Text(
                                      'xt.muSurahMeta'.tr(
                                        args: [
                                          (mekki
                                                  ? 'xt.muMeccan'
                                                  : 'xt.muMedinan')
                                              .tr(),
                                          s.ayahCount.toString(),
                                          juzForPage(p).toString(),
                                        ],
                                      ),
                                      style: TextStyle(
                                        color: c.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          s.arabic,
                                          textDirection: TextDirection.rtl,
                                          style: AppTypography.arabic(
                                            fontSize: 16,
                                            color: c.gold,
                                          ),
                                        ),
                                        Text(
                                          'xt.muPageNum'.tr(args: [p.toString()]),
                                          style: TextStyle(
                                            color: c.textTertiary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _pc.jumpToPage(p - 1);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        ListView.builder(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: 30,
                          itemBuilder: (ctx2, i) {
                            final p = juzStartPage[i];
                            final (jStart, jEnd) = juzPageSpan(i + 1);
                            // Cüzün başladığı sure — satırda ipucu olarak.
                            final sNo = surahForPage(p);
                            final sName =
                                surahs
                                    .where((x) => x.number == sNo)
                                    .map((x) => x.name(lang))
                                    .firstOrNull ??
                                '';
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 15,
                                backgroundColor: c.gold.withValues(alpha: 0.14),
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: c.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(
                                'xt.muJuzLabel'.tr(args: [(i + 1).toString()]),
                              ),
                              subtitle: Text(
                                'xt.muJuzStartsAt'.tr(
                                  args: [
                                    sName,
                                    (jEnd - jStart + 1).toString(),
                                  ],
                                ),
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: Text(
                                'xt.muPageRange'.tr(
                                  args: [jStart.toString(), jEnd.toString()],
                                ),
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pc.jumpToPage(p - 1);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Sayfadaki sureyi çal/duraklat (mushaf içi Kur'ân Okuyucu).
  Future<void> _togglePlay(int surahNo, String surahName) async {
    final st = ref.read(quranAudioControllerProvider);
    final ctrl = ref.read(quranAudioControllerProvider.notifier);
    if (st.surahNumber == surahNo) {
      await ctrl.toggle();
      return;
    }
    try {
      final verses = await ref.read(versesProvider(surahNo).future);
      final tracks = buildQuranTracks(
        surahNo,
        surahName,
        verses,
        quranWallpaperArt(ref, surahNo),
      );
      if (tracks.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('xt.muAudioComingSoon'.tr()),
          ),
        );
        return;
      }
      // Çevrimdışı + indirilmemiş → bilgi ver (kullanıcı 2026-06-15).
      if (!await ctrl.canPlay(tracks)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('xt.muNoInternet'.tr()),
          ),
        );
        return;
      }
      await ctrl.play(surahNo, surahName, tracks, 0);
    } catch (_) {}
  }

  /// "Sayfaya git" — sayfa rozetine dokununca.
  Future<void> _jumpDialog() async {
    final c = context.colors;
    final ctrl = TextEditingController(text: '$_page')
      ..selection = TextSelection(baseOffset: 0, extentOffset: '$_page'.length);
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('xt.muGoToPageTitle'.tr()),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: '1 - 604'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text('xt.muGo'.tr()),
          ),
        ],
      ),
    );
    if (target == null) return;
    final p = target.clamp(1, mushafPageCount);
    _pc.jumpToPage(p - 1);
  }

  @override
  void dispose() {
    // Mushaftan çıkarken son sayfada yeterince kalındıysa say (604 dahil).
    _countCurrentIfDwelt();
    WidgetsBinding.instance.removeObserver(this);
    _pc.dispose();
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.langCode;
    final surahs = ref.watch(surahsProvider).value ?? const <Surah>[];
    final sNo = surahForPage(_page);
    final m = surahs.where((x) => x.number == sNo);
    final surahName = m.isEmpty ? 'Sure $sNo' : m.first.name(lang);

    // Sayaçlar: sure-içi (x/y) + cüz-içi (i/j) — referans tasarımdaki gibi.
    final juz = juzForPage(_page);
    final (sStart, sEnd) = surahPageSpan(sNo);
    final (jStart, jEnd) = juzPageSpan(juz);
    final sIdx = (_page - sStart + 1).clamp(1, sEnd - sStart + 1);
    final jIdx = (_page - jStart + 1).clamp(1, jEnd - jStart + 1);

    final audio = ref.watch(quranAudioControllerProvider);
    final playingThis = audio.surahNumber == sNo && audio.playing;

    return SelayaScaffold(
      title: 'xt.muSurahTitle'.tr(
        args: [
          sNo.toString(),
          surahName,
          sIdx.toString(),
          (sEnd - sStart + 1).toString(),
        ],
      ),
      showBack: true,
      actions: [
        // Madde 4: sayfadaki ayetlerin mealini (çeviri) alta aç/kapa.
        IconButton(
          tooltip: 'xt.muMeal'.tr(),
          icon: Icon(
            Icons.translate_rounded,
            color: _showMeal ? c.gold : c.textSecondary,
          ),
          onPressed: () => setState(() => _showMeal = !_showMeal),
        ),
        IconButton(
          tooltip: 'xt.muPickSurahJuz'.tr(),
          icon: Icon(Icons.format_list_bulleted_rounded, color: c.gold),
          onPressed: _openPicker,
        ),
      ],
      body: Column(
        children: [
          // Sayfa · Cüz bilgi satırı (başlığın hemen altı) — dokun → seçici.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openPicker,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'xt.muPageJuzInfo'.tr(
                  args: [
                    _page.toString(),
                    mushafPageCount.toString(),
                    juz.toString(),
                    jIdx.toString(),
                    (jEnd - jStart + 1).toString(),
                  ],
                ),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: c.textSecondary),
              ),
            ),
          ),
          Expanded(
            // Gerçek mushaf gibi SAĞDAN SOLA: reverse → ileri sayfa sola kayar.
            child: PageView.builder(
              controller: _pc,
              reverse: true,
              itemCount: mushafPageCount,
              onPageChanged: _onPage,
              itemBuilder: (context, index) {
                final page = index + 1;
                final content = Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                  child: GestureDetector(
                    // Çift dokun → dokunduğun yere yakınlaş; tekrar → sıfırla.
                    onDoubleTapDown: (d) => _doubleTapAt = d,
                    onDoubleTap: _onDoubleTap,
                    child: InteractiveViewer(
                      // Controller YALNIZ görünen sayfada — komşular kendi
                      // iç durumunu kullanır, birbirini ezemez.
                      transformationController: index == _page - 1
                          ? _zoom
                          : null,
                      maxScale: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          // Mushaf sayfası beyaz zemin üzerinde okunur (koyu
                          // temada da kâğıt hissi).
                          color: const Color(0xFFFDF8EE),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: c.gold.withValues(alpha: 0.35),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.all(6),
                        width: double.infinity,
                        child: AppImage.cdn(
                          mushafPageUrl(page),
                          fit: BoxFit.contain,
                          // Sayfa görseli CDN'den İLK inerken küçük "indiriliyor"
                          // bilgisi (kullanıcı 2026-06-17). İkinci görüşte disk
                          // önbelleğinden anında gelir → gösterge çıkmaz.
                          loadingPlaceholder: const _MushafPageLoading(),
                        ),
                      ),
                    ),
                  ),
                );
                // Sayfa geçişi NORMAL ve yumuşak (düz kaydırma) — yaprak/3D
                // efektleri denendi, kafa karıştırdığı için kaldırıldı.
                return content;
              },
            ),
          ),
          // Madde 4: alt MEAL paneli — sayfadaki ayetlerin seçili dile göre meali
          // (çeviri toggle ile aç/kapa). Sayfa çevrilince otomatik güncellenir.
          if (_showMeal)
            _MushafMealPanel(
              page: _page,
              lang: lang,
              onClose: () => setState(() => _showMeal = false),
            ),
          // İbadeti bölmeyen küçük "ses indiriliyor" rozeti (kullanıcı 2026-06-17).
          const QuranCachingBadge(),
          // 🎧 Mushaf içi Kur'ân Okuyucu: sayfadaki sureyi çal/duraklat.
          // (Tam kumanda global mini'den gelir — app.dart overlay'i.)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                // ◀ Önceki sure (kullanıcı 2026-06-15: mushaf navigasyonu).
                IconButton(
                  tooltip: 'xt.muPrevSurah'.tr(),
                  icon: const Icon(Icons.skip_previous_rounded),
                  color: sNo > 1
                      ? c.gold
                      : c.textTertiary.withValues(alpha: 0.4),
                  onPressed: sNo > 1
                      ? () => _pc.jumpToPage(pageForSurah(sNo - 1) - 1)
                      : null,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _togglePlay(sNo, surahName),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: c.gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: c.gold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            playingThis
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: c.gold,
                            size: 26,
                          ),
                          const Gap.md(),
                          Expanded(
                            child: Text(
                              playingThis
                                  ? 'xt.muPlayingPause'.tr(args: [surahName])
                                  : 'xt.muReciterLabel'.tr(args: [surahName]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: c.gold,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ▶ Sonraki sure.
                IconButton(
                  tooltip: 'xt.muNextSurah'.tr(),
                  icon: const Icon(Icons.skip_next_rounded),
                  color: sNo < 114
                      ? c.gold
                      : c.textTertiary.withValues(alpha: 0.4),
                  onPressed: sNo < 114
                      ? () => _pc.jumpToPage(pageForSurah(sNo + 1) - 1)
                      : null,
                ),
                GestureDetector(
                  onTap: _jumpDialog,
                  child: _Chip(
                    text: 'xt.muPageNum'.tr(args: [_page.toString()]),
                    accent: true,
                  ),
                ),
              ],
            ),
          ),
          // Kaynak (küçük yazı) — hat + görsel kaynağı atfı.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Text(
              'xt.muSourceAttribution'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: c.textTertiary,
                fontSize: 10,
              ),
            ),
          ),
          // Global mini çalar görünürken alt şerit (Kur'ân Okuyucu + atıf) onun
          // altında kalmasın: mini kadar boşluk. Eski bottomNavigationBar
          // düzenindeki sıralama korunur — bar üstte, mini en altta.
          ValueListenableBuilder<double>(
            valueListenable: miniPlayerHeight,
            builder: (_, h, _) => SizedBox(height: h),
          ),
        ],
      ),
    );
  }
}

/// Mushaf sayfası CDN'den inerken sayfanın ortasında gösterilen küçük
/// "Sayfa indiriliyor…" bilgisi (kullanıcı 2026-06-17). Sayfa zaten boşken
/// göründüğünden küçük gösterge ibadeti bölmez; disk önbelleğinden gelen
/// sayfalarda hiç çıkmaz.
class _MushafPageLoading extends StatelessWidget {
  const _MushafPageLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.gold.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.gold,
              ),
            ),
            const Gap.sm(),
            Text(
              'xt.muLoadingPage'.tr(),
              style: TextStyle(
                color: context.colors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool accent;
  const _Chip({required this.text, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent ? c.gold.withValues(alpha: 0.16) : c.surfaceAlt,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: accent ? c.gold.withValues(alpha: 0.5) : c.border,
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accent ? c.gold : c.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 📖 Madde 4 — Mushaf alt MEAL paneli. Açık sayfadaki ayetlerin seçili dile
/// göre meali (offline verses_NNN.json). Sayfa çevrilince [page] değişir →
/// provider yeniden çekilir. Mealler yetkili/yayınlanmış çevirilerdir.
class _MushafMealPanel extends ConsumerWidget {
  final int page;
  final String lang;
  final VoidCallback onClose;
  const _MushafMealPanel({
    required this.page,
    required this.lang,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(mushafPageVersesProvider(page));
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.30,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.gold.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık şeridi: "Meal" + kapat.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
            child: Row(
              children: [
                Icon(Icons.translate_rounded, size: 16, color: c.gold),
                const Gap.sm(),
                Text(
                  'xt.muMeal'.tr(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: c.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: c.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => Center(
                child: Text(
                  'xt.muMealEmpty'.tr(),
                  style: TextStyle(color: c.textTertiary),
                ),
              ),
              data: (items) => items.isEmpty
                  ? Center(
                      child: Text(
                        'xt.muMealEmpty'.tr(),
                        style: TextStyle(color: c.textTertiary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 16,
                        color: c.border.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (ctx, i) {
                        final it = items[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ayet rozeti: "sure:ayet" (ör. 2:255).
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: c.gold.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${it.surah}:${it.verse.ayah}',
                                style: TextStyle(
                                  color: c.gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Gap.md(),
                            Expanded(
                              child: Text(
                                it.verse.meaning(lang),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: c.textSecondary,
                                      height: 1.45,
                                    ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
