import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
// ScrollCacheExtent (ListView.builder'da çalan ayete kaydırma için ön-kurulan
// alan) yalnız rendering katmanında — material.dart yeniden ihraç etmiyor.
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/cdn.dart';
import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/content_detail_dialog.dart';
import '../../../core/widgets/instant_swipe.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../data/mushaf_meta.dart';
import '../data/quran_favorites.dart';
import '../data/quran_audio_controller.dart';
import '../data/quran_tracks.dart';

const _bismillah = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

class QuranReaderScreen extends ConsumerStatefulWidget {
  final int surahNumber;
  const QuranReaderScreen({super.key, required this.surahNumber});

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  final Map<int, GlobalKey> _keys = {};
  // ListView.builder tembel → uzaktaki ayet kartı kurulu olmayabilir; çalan
  // ayete atlamak (ensureVisible boşa düştüğünde) için tahmini ofset kaydırması.
  final ScrollController _scrollCtrl = ScrollController();
  StreamSubscription<int?>? _idxSub;
  int? _currentAyah;
  bool _wasActive = false; // bu sure çalıyordu (örtülü geçiş yakalama için)
  double _endOverscroll = 0; // alt uçta birikmiş aşırı-kaydırma (sonraki sure)
  double _startOverscroll = 0; // üst uçta birikmiş aşırı-kaydırma (önceki sure)
  bool _surahNavLock = false;
  // Ayet numaraları (ses listesi sırasında) — index → doğru ayet eşlemesi.
  List<int> _audibleAyahs = const [];
  List<MediaTrack> _tracks = const [];

  QuranAudioController get _ctrl =>
      ref.read(quranAudioControllerProvider.notifier);

  bool get _isActiveSurah =>
      ref.read(quranAudioControllerProvider).surahNumber == widget.surahNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(sharedPreferencesProvider)
          .setInt(PrefKeys.quranLastRead, widget.surahNumber);
    });
    // Çalan ayet → vurgula + kaydır (yalnızca bu sure çalıyorsa).
    _idxSub = _ctrl.currentIndexStream.listen((idx) {
      if (!mounted || !_isActiveSurah || idx == null) return;
      // Çalmayı bu sayfa başlatmadıysa (otomatik sure geçişi / kuyruktan
      // seçim) ayet eşlemesini kontrolcünün kuyruğundan devral — yoksa
      // vurgu + otomatik kaydırma yeni surede ÇALIŞMAZDI.
      if (_audibleAyahs.isEmpty) _adoptControllerQueue();
      if (idx >= _audibleAyahs.length) return;
      final ayah = _audibleAyahs[idx];
      setState(() => _currentAyah = ayah);
      _ensureVisible(ayah);
    });
    // Sayfa açıldığında bu sure ZATEN çalıyorsa (otomatik geçiş sonrası
    // pushReplacement ile gelindi) hemen bağlan + çalan ayete kaydır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isActiveSurah && _audibleAyahs.isEmpty) {
        _adoptControllerQueue();
      }
    });
  }

  /// Kontrolcüde çalan kuyruk bu surenin kuyruğuysa ayet eşlemesini ondan
  /// kurar (track id'leri `<sure>_<ayet>`). Çalan ayeti hemen vurgular.
  void _adoptControllerQueue() {
    final ts = _ctrl.tracks;
    final prefix = '${widget.surahNumber}_';
    final ayahs = <int>[];
    for (final t in ts) {
      if (!t.id.startsWith(prefix)) return; // kuyruk başka sureye ait
      final a = int.tryParse(t.id.substring(prefix.length));
      if (a == null) return;
      ayahs.add(a);
    }
    if (ayahs.isEmpty) return;
    _audibleAyahs = ayahs;
    _tracks = List.of(ts);
    final idx = _ctrl.currentIndex;
    if (idx >= 0 && idx < _audibleAyahs.length) {
      setState(() => _currentAyah = _audibleAyahs[idx]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentAyah != null) _ensureVisible(_currentAyah!);
      });
    }
  }

  @override
  void dispose() {
    _idxSub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Sayfa sure ile SINIRLI değil: en alttan devam edince (veya alttaki karta
  /// dokununca) sonraki sureye akar — kesintisiz gezinti.
  void _goToSurah(int n) {
    if (_surahNavLock || n < 1 || n > 114) return;
    _surahNavLock = true;
    // go (pushReplacement değil): okuyucu kabuk-altı rota — branch stack'i
    // [liste, okuyucu] kalır, geri tuşu listeye döner, alt menü hep görünür.
    context.go('${Routes.quranReader}/$n');
  }

  void _ensureVisible(int ayah) {
    final ctx = _keys[ayah]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350),
          alignment: 0.25,
          curve: Curves.easeInOut);
      return;
    }
    // Tembel listede hedef kart henüz KURULU değil (görünümden uzakta — örn.
    // sure zaten ileri bir ayette çalarken okuyucu yeni açıldı). ensureVisible
    // boşa düşer → ayet sırasından tahmini piksel ofsetine atla (kart o civarda
    // kurulur), sonraki karede ensureVisible'la ince ayar yap. Tahmin tutmasa
    // bile bir sonraki ayet geçişinde yakın olduğundan kendini düzeltir.
    if (!_scrollCtrl.hasClients) return;
    const leadEst = 540.0; // önceki-sure kartı + başlık + besmele kabası
    const avgVerse = 340.0; // ortalama ayet kartı yüksekliği (kaba tahmin)
    final target = (leadEst + (ayah - 1) * avgVerse)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx2 = _keys[ayah]?.currentContext;
      if (ctx2 != null) {
        Scrollable.ensureVisible(ctx2,
            duration: const Duration(milliseconds: 200), alignment: 0.25);
      }
    });
  }

  /// Kapak görselini günlük duvar kâğıtlarından seçer (sure no'ya göre sabit).
  String _wallpaperArt() {
    final wps = ref.read(wallpapersProvider).value ?? const <Wallpaper>[];
    if (wps.isEmpty) {
      return '${SelayaCdn.cdnBase}/images/wallpapers/wp_calligraphy_1.jpg';
    }
    final img = wps[widget.surahNumber % wps.length].image;
    if (img.startsWith('http')) return img;
    final u = SelayaCdn.urlForAsset(img);
    return u.isNotEmpty
        ? u
        : '${SelayaCdn.cdnBase}/images/wallpapers/wp_calligraphy_1.jpg';
  }

  /// Ayet seslerini (Worker proxy) MediaTrack listesi olarak hazırlar.
  void _buildTracks(List<Verse> verses, String surahName) {
    if (_tracks.isNotEmpty) return;
    final audible = [for (final v in verses) if (v.audio != null) v];
    if (audible.isEmpty) return;
    _audibleAyahs = [for (final v in audible) v.ayah];
    final art = _wallpaperArt();
    _tracks = [
      for (final v in audible)
        MediaTrack(
          id: '${widget.surahNumber}_${v.ayah}',
          url:
              '${SelayaCdn.apiBase}/v1/quran-audio/${widget.surahNumber}/${v.ayah}',
          title: '$surahName · ${v.ayah}',
          artUri: art,
        ),
    ];
  }

  /// Ekranda O AN GÖRÜNEN ilk ayetin index'i — kullanıcı "5. sayfaya" inmişse
  /// "Sureyi Dinle" baştan değil ORADAN okumaya başlar. Tile'ların GlobalKey'leri
  /// üzerinden bakılır (yalnız ekrandakiler bağlı olduğundan ucuzdur).
  int _firstVisibleIndex(List<Verse> verses) {
    final topLimit =
        MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    int? bestAyah;
    var bestDy = double.infinity;
    _keys.forEach((ayah, key) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) return;
      final dy = box.localToGlobal(Offset.zero).dy;
      // Kartın altı app bar'ın üstünde kalmışsa o ayet geçilmiş demektir.
      if (dy + box.size.height < topLimit + 40) return;
      if (dy < bestDy) {
        bestDy = dy;
        bestAyah = ayah;
      }
    });
    if (bestAyah == null) return 0;
    final i = verses.indexWhere((v) => v.ayah == bestAyah);
    return i < 0 ? 0 : i;
  }

  Future<void> _toggleSurah(List<Verse> verses, String surahName) async {
    _buildTracks(verses, surahName);
    if (_tracks.isEmpty) return;
    if (_isActiveSurah) {
      await _ctrl.toggle();
    } else {
      // Bulunduğun yerden başla: görünen ilk ayetten itibaren oku (sesi
      // olmayan ayetse sonraki sesliye yuvarlanır). Baştan isteyen için
      // başlıktaki küçük "Baştan" düğmesi var.
      final vi = _firstVisibleIndex(verses);
      var audioIndex = -1;
      for (var i = vi; i < verses.length; i++) {
        final ai = _audibleAyahs.indexOf(verses[i].ayah);
        if (ai >= 0) {
          audioIndex = ai;
          break;
        }
      }
      await _ctrl.play(
          widget.surahNumber, surahName, _tracks, audioIndex < 0 ? 0 : audioIndex);
    }
  }

  /// "Baştan" — sure 1. ayetten okunur (çalıyorsa başa sarar).
  Future<void> _listenFromStart(List<Verse> verses, String surahName) async {
    _buildTracks(verses, surahName);
    if (_tracks.isEmpty) return;
    if (_isActiveSurah) {
      await _ctrl.jumpTo(0);
      if (!ref.read(quranAudioControllerProvider).playing) {
        await _ctrl.toggle();
      }
    } else {
      await _ctrl.play(widget.surahNumber, surahName, _tracks, 0);
    }
  }

  Future<void> _playAyah(
      List<Verse> verses, int index, String surahName) async {
    _buildTracks(verses, surahName);
    final audioIndex = _audibleAyahs.indexOf(verses[index].ayah);
    if (audioIndex < 0) return;
    if (_isActiveSurah) {
      await _ctrl.jumpTo(audioIndex);
      if (!ref.read(quranAudioControllerProvider).playing) {
        await _ctrl.toggle();
      }
    } else {
      await _ctrl.play(widget.surahNumber, surahName, _tracks, audioIndex);
    }
  }

  /// Ayetleri tek tek, ortada açılan büyük kartta gösterir; ◀▶ ile gezilir,
  /// sesi olan ayet doğrudan oradan çalınabilir. Çalan ayet biliniyorsa ondan
  /// açar. SON ayetten ▶ → SONRAKİ surenin popup'ı; İLK ayetten ◀ → önceki
  /// surenin son ayeti → kullanıcı popup içinde TÜM Kur'an'ı gezebilir.
  void _openVersesPopup(List<Verse> verses, String surahName, String lang,
      {int? startIndex}) {
    _openVersesPopupFor(widget.surahNumber, verses, surahName, lang,
        startIndex: startIndex);
  }

  void _openVersesPopupFor(
      int surahNo, List<Verse> verses, String surahName, String lang,
      {int? startIndex}) {
    if (verses.isEmpty) return;
    final mine = surahNo == widget.surahNumber;
    final items = [
      for (var i = 0; i < verses.length; i++)
        ContentDetailItem(
          title: '$surahName ${verses[i].ayah}',
          arabic: verses[i].arabic,
          transliteration: verses[i].transliteration,
          text: verses[i].meaning(lang),
          reference: '$surahName · ${verses[i].ayah}',
          shareLabel: surahName,
          // Sesi olan ayetlerde "Oku/Play" düğmesi (yoksa _playAyah erken döner).
          actionLabel: verses[i].audio == null
              ? ''
              : (lang == 'tr' ? 'Oku' : 'Play'),
          actionIcon: Icons.play_arrow_rounded,
          onAction: verses[i].audio == null
              ? null
              : (ctx) {
                  Navigator.of(ctx).pop();
                  if (mine) {
                    _playAyah(verses, i, surahName);
                  } else {
                    // Başka surenin ayeti: kuyruğu kur + o ayetten çal.
                    // Çalmaya başlayınca sayfa zaten o sureye atlar (ref.listen).
                    final tracks = buildQuranTracks(surahNo, surahName, verses,
                        quranWallpaperArt(ref, surahNo));
                    final audible = [
                      for (final v in verses)
                        if (v.audio != null) v.ayah
                    ];
                    final ai = audible.indexOf(verses[i].ayah);
                    if (tracks.isNotEmpty) {
                      _ctrl.play(surahNo, surahName, tracks, ai < 0 ? 0 : ai);
                    }
                  }
                },
        ),
    ];
    final initial = startIndex ??
        (mine && _currentAyah != null
            ? verses.indexWhere((v) => v.ayah == _currentAyah)
            : 0);
    showContentDetail(
      context,
      items,
      initial < 0 ? 0 : initial,
      headerTitle: surahName,
      onReachEnd: surahNo >= 114
          ? null
          : (ctx) {
              Navigator.of(ctx).pop();
              _openSurahPopup(surahNo + 1, lang, atEnd: false);
            },
      onReachStart: surahNo <= 1
          ? null
          : (ctx) {
              Navigator.of(ctx).pop();
              _openSurahPopup(surahNo - 1, lang, atEnd: true);
            },
    );
  }

  /// [n] suresinin ayetlerini yükleyip popup'ını açar (sure-gezinti köprüsü).
  Future<void> _openSurahPopup(int n, String lang, {required bool atEnd}) async {
    if (n < 1 || n > 114) return;
    try {
      final verses = await ref.read(versesProvider(n).future);
      if (!mounted || verses.isEmpty) return;
      final surahs = ref.read(surahsProvider).value ?? const <Surah>[];
      var name = 'Sure $n';
      for (final s in surahs) {
        if (s.number == n) {
          name = s.name(lang);
          break;
        }
      }
      _openVersesPopupFor(n, verses, name, lang,
          startIndex: atEnd ? verses.length - 1 : 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final surahs = ref.watch(surahsProvider).value ?? const <Surah>[];
    final matches = surahs.where((s) => s.number == widget.surahNumber);
    final surah = matches.isEmpty ? null : matches.first;
    final versesAsync = ref.watch(versesProvider(widget.surahNumber));
    final c = context.colors;

    // Bu sayfanın suresi çalarken ses BAŞKA bir sureye geçtiyse (otomatik
    // sıradaki-sure geçişi veya kuyruktan seçim) sayfa da o sureye atlar —
    // yoksa çalar bar kayboluyor, sayfa eski surede "takılı" görünüyordu.
    ref.listen<QuranAudioState>(quranAudioControllerProvider, (prev, next) {
      if (!mounted) return;
      // Sayfa GÖRÜNMÜYORKEN (başka sekme aktif → IndexedStack offstage, veya
      // üstte opak route var) navigasyon YAPMA — yoksa her otomatik sure
      // geçişi kullanıcıyı gezindiği sekmeden Kur'an okuyucusuna geri çeker.
      // Görünür olunca aşağıdaki _wasActive bloğu sayfayı doğru sureye taşır.
      if (!TickerMode.getValuesNotifier(context).value.enabled) return;
      if (prev?.surahNumber == widget.surahNumber &&
          next.surahNumber != null &&
          next.surahNumber != widget.surahNumber) {
        context.go('${Routes.quranReader}/${next.surahNumber}');
      }
    });

    final st = ref.watch(quranAudioControllerProvider);
    final active = st.surahNumber == widget.surahNumber;
    final isPlaying = active && st.playing;
    final currentAyah = active ? _currentAyah : null;

    // TickerMode'a BAĞIMLILIK: sayfa offstage'den görünür hâle gelince rebuild
    // tetiklenir → aşağıdaki yakalama bloğu tam o anda çalışır.
    final pageVisible = TickerMode.valuesOf(context).enabled;

    // Sure geçişi bu sayfa ÖRTÜLÜYKEN (now-playing açık / başka sekmedeyken)
    // olursa ref.listen bilerek atlar → görünür olunca yakala: bu sure
    // çalıyordu ama artık başka sure çalıyorsa sayfayı ona taşı.
    if (active) {
      _wasActive = true;
    } else if (_wasActive &&
        st.surahNumber != null &&
        pageVisible &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      _wasActive = false;
      final target = st.surahNumber;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && target != null) {
          context.go('${Routes.quranReader}/$target');
        }
      });
    }

    return SelayaScaffold(
      title: surah?.name(lang) ?? 'quran.title'.tr(),
      showBack: true,
      bottomBar: active
          ? _QuranTransport(
              surahName: surah?.name(lang) ?? 'quran.title'.tr(),
              playing: isPlaying,
              loading: st.loading,
              ctrl: _ctrl,
            )
          : null,
      actions: [
        // ❤️ Favori — sure favorisi (Kur'an listesindeki kalple AYNI kayıt;
        // Beğendiklerim'in "Sureler" bölümüne düşer). Yâsîn dahil her surede.
        Builder(builder: (context) {
          final fav =
              ref.watch(quranFavoritesProvider).contains(widget.surahNumber);
          return IconButton(
            tooltip: lang == 'tr'
                ? (fav ? 'Favoriden çıkar' : 'Favorilere ekle')
                : (fav ? 'Unfavourite' : 'Favourite'),
            icon: Icon(fav ? AppIcons.favoriteFilled : AppIcons.favorite,
                color: fav ? c.danger : c.gold),
            onPressed: () => ref
                .read(quranFavoritesProvider.notifier)
                .toggle(widget.surahNumber),
          );
        }),
        // 📖 Mushaf Modu — bu surenin sayfasından gerçek mushaf görünümü.
        IconButton(
          tooltip: lang == 'tr' ? 'Mushaf modu' : 'Mushaf view',
          icon: Icon(Icons.auto_stories_rounded, color: c.gold),
          onPressed: () => context.go(Routes.mushaf,
              extra: pageForSurah(widget.surahNumber)),
        ),
        versesAsync.maybeWhen(
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: lang == 'tr' ? 'Ayetleri tek tek aç' : 'Browse verses',
                  icon: Icon(Icons.grid_view_rounded, color: c.gold),
                  onPressed: () =>
                      _openVersesPopup(list, surah?.name(lang) ?? 'Sure', lang),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
        versesAsync.maybeWhen(
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'quran.listenSurah'.tr(),
                  icon: Icon(isPlaying ? AppIcons.mute : AppIcons.playCircle,
                      color: c.gold),
                  onPressed: () =>
                      _toggleSurah(list, surah?.name(lang) ?? 'Sure'),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
      body: versesAsync.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        // Sayfa SURE İLE SINIRLI DEĞİL: en alttan fazladan çekince (90px
        // aşırı-kaydırma) veya alttaki karta dokununca SONRAKİ sureye akar.
        data: (list) => NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification) {
              _endOverscroll = 0;
              _startOverscroll = 0;
            }
            if (n is OverscrollNotification &&
                n.overscroll > 0 &&
                n.metrics.pixels >= n.metrics.maxScrollExtent) {
              _endOverscroll += n.overscroll;
              if (_endOverscroll > 90) {
                _goToSurah(widget.surahNumber + 1);
              }
            }
            // Üst uçtan fazladan çekince ÖNCEKİ sureye (başından) geç —
            // alttaki mekanizmanın simetriği. Fâtiha'da (sure 1) kapalı.
            if (n is OverscrollNotification &&
                n.overscroll < 0 &&
                widget.surahNumber > 1 &&
                n.metrics.pixels <= n.metrics.minScrollExtent) {
              _startOverscroll += -n.overscroll;
              if (_startOverscroll > 90) {
                _goToSurah(widget.surahNumber - 1);
              }
            }
            return false;
          },
          child: Builder(builder: (context) {
            // PERF: Eskiden ListView(children:[...]) TÜM ayetleri (Bakara 286,
            // Yâsîn 83) açılışta kurar + her ayet değişiminde setState hepsini
            // YENİDEN çizerdi → "okunurken donma". Artık ListView.builder:
            // başlık/kartlar leading, ayetler ARADA lazy, sonraki-sure trailing
            // → yalnız görünen ~6 kart kurulur/yeniden çizilir.
            final leading = <Widget>[
              // Üstte "Önceki Sure" ipucu kartı — dokun ya da üstten fazladan
              // çek (alttaki "Sonraki Sure" ile aynı dil; sure 1'de yok).
              if (widget.surahNumber > 1) ...[
                _PrevSurahCard(
                  surahs: surahs,
                  prev: widget.surahNumber - 1,
                  lang: lang,
                  onTap: () => _goToSurah(widget.surahNumber - 1),
                ),
                const Gap.base(),
              ],
              if (surah != null)
                _SurahHeader(
                  surah: surah,
                  lang: lang,
                  playing: isPlaying,
                  onListen: list.isEmpty
                      ? null
                      : () => _toggleSurah(list, surah.name(lang)),
                  onListenFromStart: list.isEmpty
                      ? null
                      : () => _listenFromStart(list, surah.name(lang)),
                ),
              const Gap.base(),
              if (widget.surahNumber != 1 && widget.surahNumber != 9)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(_bismillah,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.arabic(fontSize: 26, color: c.gold)),
                ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: SelayaEmpty(
                    icon: AppIcons.book,
                    message: lang == 'tr'
                        ? 'Bu surenin tam metni yakında eklenecek.\nSık okunan kısa sureler (Fâtiha, Kadir, Fil–Nâs arası) hazır.'
                        : 'Full text for this surah is coming soon.\nCommon short surahs (Al-Fatiha, Al-Qadr, Al-Fil–An-Nas) are ready.',
                  ),
                ),
            ];
            final trailing = <Widget>[
              if (widget.surahNumber < 114)
                _NextSurahCard(
                  surahs: surahs,
                  next: widget.surahNumber + 1,
                  lang: lang,
                  onTap: () => _goToSurah(widget.surahNumber + 1),
                ),
            ];
            return ListView.builder(
              controller: _scrollCtrl,
              // ensureVisible (çalan ayete kaydırma) hedef kartın KURULMUŞ
              // olmasını ister → ekran altındaki birkaç ayeti önden kur ki
              // ardışık oynatmada takip kopmasın.
              scrollCacheExtent: const ScrollCacheExtent.pixels(1200),
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm,
                  AppSpacing.base, AppSpacing.xxxl),
              itemCount: leading.length + list.length + trailing.length,
              itemBuilder: (context, i) {
                if (i < leading.length) return leading[i];
                final vi = i - leading.length;
                if (vi >= list.length) return trailing[vi - list.length];
                final v = list[vi];
                return _VerseTile(
                  key: _keys.putIfAbsent(v.ayah, () => GlobalKey()),
                  verse: v,
                  lang: lang,
                  playing: currentAyah == v.ayah,
                  onPlay: () => _playAyah(list, vi, surah?.name(lang) ?? 'Sure'),
                  // Karta dokun → bu ayetten popup açılır (oradan tüm sureler
                  // ◀▶ ile gezilebilir + Oku ile çalınabilir).
                  onTap: () => _openVersesPopup(
                      list, surah?.name(lang) ?? 'Sure', lang,
                      startIndex: vi),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

/// Sayfa başındaki "Önceki Sure" kartı — dokun ya da üstten fazladan çek.
/// Önceki sure her zaman BAŞINDAN açılır.
class _PrevSurahCard extends StatelessWidget {
  final List<Surah> surahs;
  final int prev;
  final String lang;
  final VoidCallback onTap;
  const _PrevSurahCard(
      {required this.surahs,
      required this.prev,
      required this.lang,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = surahs.where((s) => s.number == prev);
    final s = m.isEmpty ? null : m.first;
    return SelayaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.swipe_down_rounded, color: c.gold, size: 22),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang == 'tr' ? 'Önceki Sure' : 'Previous Surah',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: c.textTertiary)),
                Text(s?.name(lang) ?? 'Sure $prev',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: c.gold, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Icon(Icons.arrow_back_rounded, color: c.gold),
        ],
      ),
    );
  }
}

/// Sayfa sonundaki "Sonraki Sure" kartı — dokun ya da fazladan yukarı çek.
class _NextSurahCard extends StatelessWidget {
  final List<Surah> surahs;
  final int next;
  final String lang;
  final VoidCallback onTap;
  const _NextSurahCard(
      {required this.surahs,
      required this.next,
      required this.lang,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = surahs.where((s) => s.number == next);
    final s = m.isEmpty ? null : m.first;
    return SelayaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.swipe_up_rounded, color: c.gold, size: 22),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang == 'tr' ? 'Sonraki Sure' : 'Next Surah',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: c.textTertiary)),
                Text(s?.name(lang) ?? 'Sure $next',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: c.gold, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: c.gold),
        ],
      ),
    );
  }
}

/// Okuyucunun altında, bu sure çalarken görünen kumanda barı (önceki / oynat-
/// duraklat / sonraki / durdur). Arka plan + bildirim handler'dan; bu bar
/// okuyucudayken pratik kontrol sağlar.
class _QuranTransport extends StatelessWidget {
  final String surahName;
  final bool playing;
  final bool loading;
  final QuranAudioController ctrl;
  const _QuranTransport({
    required this.surahName,
    required this.playing,
    required this.loading,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cover = Container(
      color: c.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(Icons.queue_music_rounded, color: c.gold, size: 20),
    );
    // Tam-ekran now-playing KALDIRILDI → bar sadece play/stop + ilerleme
    // gösterir; yukarı-çek/dokun ile genişleme yok (sade oynatıcı).
    return InstantSwipe(
      onUp: () {},
      child: Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // İnce İLERLEME çizgisi — çalan ayetin konumu (global mini'dekiyle
          // aynı). Eskiden bu barda HİÇ yoktu; "Sureyi Oku" ile başlatınca
          // çizgisiz görünüyordu (kullanıcı bunu 'geç çıkıyor' diye bildirdi —
          // gördüğü çizgi okuyucudan çıkınca beliren mini'nindi).
          StreamBuilder<Duration?>(
            stream: ctrl.durationStream,
            builder: (context, dSnap) {
              final total = dSnap.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: ctrl.positionStream,
                builder: (context, pSnap) {
                  final pos = pSnap.data ?? Duration.zero;
                  final f = total.inMilliseconds == 0
                      ? 0.0
                      : (pos.inMilliseconds / total.inMilliseconds)
                          .clamp(0.0, 1.0);
                  return SizedBox(
                    height: 3,
                    width: double.infinity,
                    child: ColoredBox(
                      color: c.border.withValues(alpha: 0.5),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: f,
                        child: ColoredBox(color: c.gold),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Gap.sm(),
          // Albüm kapağı (duvar kâğıdı) — okuma ekranı kumandasında da görünsün
          // (ana ekrandaki global mini-player'da zaten vardı).
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 42,
              height: 42,
              child: ctrl.art.isNotEmpty
                  ? Image.network(ctrl.art,
                      fit: BoxFit.cover, errorBuilder: (_, _, _) => cover)
                  : cover,
            ),
          ),
          const Gap.sm(),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(surahName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                  Row(
                    children: [
                      Icon(Icons.queue_music_rounded,
                          size: 13, color: c.textTertiary),
                      const SizedBox(width: 4),
                      Flexible(
                        // Canlı "kaçıncı ayet": parça değiştikçe kendiliğinden
                        // güncellenir; çözülemezse eski "Sıradaki ayetler".
                        child: StreamBuilder<int?>(
                          stream: ctrl.currentIndexStream,
                          builder: (context, _) {
                            final a = ctrl.currentAyahNumber;
                            final tr = context.langCode == 'tr';
                            final sub = loading
                                ? 'common.loading'.tr()
                                : a == null
                                    ? 'quran.queue'.tr()
                                    : (tr ? '$a. ayet okunuyor' : 'Verse $a');
                            return Text(sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: c.textTertiary));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            color: c.textSecondary,
            icon: const Icon(Icons.skip_previous_rounded),
            onPressed: ctrl.previous,
          ),
          IconButton(
            iconSize: 42,
            color: c.gold,
            icon: Icon(playing
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded),
            onPressed: ctrl.toggle,
          ),
          IconButton(
            color: c.textSecondary,
            icon: const Icon(Icons.skip_next_rounded),
            onPressed: ctrl.next,
          ),
          IconButton(
            color: c.textSecondary,
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: ctrl.stop,
          ),
        ],
      ),
          ),
        ],
      ),
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  final Surah surah;
  final String lang;
  final bool playing;
  final VoidCallback? onListen;

  /// Küçük "Baştan" düğmesi — sure nereden açık olursa olsun 1. ayetten okur.
  final VoidCallback? onListenFromStart;
  const _SurahHeader({
    required this.surah,
    required this.lang,
    required this.playing,
    this.onListen,
    this.onListenFromStart,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      gradient: LinearGradient(colors: [
        c.gold.withValues(alpha: 0.18),
        c.surfaceAlt,
      ]),
      child: Column(
        children: [
          Text(surah.arabic,
              textDirection: TextDirection.rtl,
              style: AppTypography.arabic(fontSize: 34, color: c.gold)),
          const Gap.xs(),
          Text(surah.name(lang), style: Theme.of(context).textTheme.titleLarge),
          Text(
            '${surah.revelation == 'meccan' ? 'quran.meccan'.tr() : 'quran.medinan'.tr()} • ${'quran.ayahCount'.tr(args: [
                  surah.ayahCount.toString()
                ])}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c.textTertiary),
          ),
          if (onListen != null) ...[
            const Gap.md(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onListen,
                  icon: Icon(playing ? AppIcons.mute : AppIcons.playCircle,
                      size: 18, color: c.gold),
                  label: Text(
                      playing ? 'quran.pause'.tr() : 'quran.listenSurah'.tr(),
                      style: TextStyle(
                          color: c.gold, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.rLg),
                  ),
                ),
                if (onListenFromStart != null) ...[
                  const Gap.sm(),
                  // "Baştan": dinleme nereden açılırsa açılsın 1. ayete döner.
                  TextButton.icon(
                    onPressed: onListenFromStart,
                    icon: Icon(Icons.restart_alt_rounded,
                        size: 18, color: c.textSecondary),
                    label: Text(lang == 'tr' ? 'Baştan' : 'From start',
                        style: TextStyle(color: c.textSecondary)),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VerseTile extends StatelessWidget {
  final Verse verse;
  final String lang;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback? onTap;
  const _VerseTile({
    super.key,
    required this.verse,
    required this.lang,
    required this.playing,
    required this.onPlay,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap, // karta dokun → ayet popup'ı (oynat düğmesi ayrı çalışır)
      child: Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: playing ? c.gold.withValues(alpha: 0.10) : c.surfaceAlt,
        borderRadius: AppRadius.rLg,
        border: Border.all(
            color: playing ? c.gold.withValues(alpha: 0.6) : c.border,
            width: playing ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: c.gold.withValues(alpha: 0.14),
                child: Text('${verse.ayah}',
                    style: TextStyle(
                        color: c.gold, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              if (playing) ...[
                const Gap.sm(),
                // ④ "Şu an okunuyor" göstergesi — çalan ayeti net işaretler.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.graphic_eq_rounded, size: 12, color: c.gold),
                      const SizedBox(width: 4),
                      Text(lang == 'tr' ? 'okunuyor' : 'reciting',
                          style: TextStyle(
                              color: c.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(playing ? AppIcons.volumeHigh : AppIcons.playCircle,
                    color: c.gold),
                onPressed: onPlay,
              ),
            ],
          ),
          const Gap.sm(),
          // Full-width so the Arabic always right-aligns (RTL) consistently —
          // otherwise a short verse sizes to its content and sits on the left.
          SizedBox(
            width: double.infinity,
            child: Text(verse.arabic,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: AppTypography.arabic(
                    fontSize: 28, color: playing ? c.gold : c.textPrimary)),
          ),
          if (verse.transliteration.isNotEmpty) ...[
            const Gap.sm(),
            Text(verse.transliteration,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.gold, fontStyle: FontStyle.italic)),
          ],
          const Gap.sm(),
          Text(verse.meaning(lang),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textSecondary, height: 1.5)),
        ],
      ),
      ),
    );
  }
}
