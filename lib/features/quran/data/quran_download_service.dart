import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../core/di/providers.dart';
import 'quran_tracks.dart';

/// İndirme durumu: hangi sureler offline indirilmiş + o an indirilmekte olanların
/// ilerlemesi (0..1).
class QuranDownloadState {
  final Set<int> downloaded; // indirilmiş sure numaraları
  final Map<int, double> progress; // indiriliyor: sure no → 0..1
  const QuranDownloadState({
    this.downloaded = const {},
    this.progress = const {},
  });

  QuranDownloadState copyWith({
    Set<int>? downloaded,
    Map<int, double>? progress,
  }) =>
      QuranDownloadState(
        downloaded: downloaded ?? this.downloaded,
        progress: progress ?? this.progress,
      );
}

/// Kur'an sure seslerini OFFLINE indirir/siler ve oynatıcı için yerel dosya
/// yollarına çevirir. İnternetsiz kullanım için (kullanıcı isteği 2026-06-14):
/// liste ekranında her surede ⬇ buton → onay → tüm ayetler cihaza iner →
/// okuyucu o sureyi yerelden çalar (akış/veri yok).
///
/// Yerel düzen: `<appDocs>/quran_audio/<sure>_<ayet>.mp3` (track id = `<sure>_<ayet>`).
/// İndirilmiş sure listesi SharedPreferences'ta saklanır → kalıcı.
class QuranDownloadController extends Notifier<QuranDownloadState> {
  Directory? _dir;
  static const _prefsKey = 'quran_downloaded_surahs_v1';

  /// En çok kaç sure offline tutulur (kullanıcı 2026-06-14: "6 adet"). 7.
  /// inince en ESKİ indirilen otomatik silinir → depolama hafif kalır,
  /// gerisini kullanıcı elle indirir. Sıra = ekleme sırası (LinkedHashSet).
  static const _maxKept = 6;

  @override
  QuranDownloadState build() {
    _init();
    return const QuranDownloadState();
  }

  Future<void> _init() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      _dir = Directory('${docs.path}/quran_audio');
      if (!await _dir!.exists()) await _dir!.create(recursive: true);
      final prefs = ref.read(sharedPreferencesProvider);
      final raw = prefs.getStringList(_prefsKey) ?? const [];
      state = state.copyWith(
          downloaded: raw.map(int.tryParse).whereType<int>().toSet());
    } catch (_) {}
  }

  File _file(String trackId) => File('${_dir!.path}/$trackId.mp3');

  bool isDownloaded(int surah) => state.downloaded.contains(surah);
  bool isDownloading(int surah) => state.progress.containsKey(surah);

  /// Oynatıcıya verilecek parça listesini çözer: sure indirilmişse YEREL dosya
  /// url'leri (offline), değilse gelen CDN url'leri. Oynatıcı bunu çağırır.
  List<MediaTrack> resolveTracks(int surah, List<MediaTrack> tracks) {
    if (_dir == null || !isDownloaded(surah)) return tracks;
    return [
      for (final t in tracks)
        _file(t.id).existsSync()
            ? MediaTrack(
                id: t.id,
                url: _file(t.id).uri.toString(),
                title: t.title,
                artUri: t.artUri)
            : t, // eksik dosya → CDN'e düş (bozulmasın)
    ];
  }

  /// Surenin tüm ayet seslerini sırayla indirir (her biri tek HTTP GET — range
  /// gerektirmez). İlerlemeyi state'e yazar; bitince downloaded'a ekler +
  /// kalıcılaştırır. "6 adet" sınırı aşılırsa en eski sureyi otomatik siler ve
  /// silinen sure numarasını döndürür (UI kullanıcıya bildirir); aksi halde null.
  Future<int?> download(int surah, List<MediaTrack> tracks) async {
    if (_dir == null || tracks.isEmpty || isDownloading(surah)) return null;
    _setProgress(surah, 0);
    var done = 0;
    for (final t in tracks) {
      try {
        final f = _file(t.id);
        if (!await f.exists()) {
          final res = await http.get(Uri.parse(t.url));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            await f.writeAsBytes(res.bodyBytes);
          }
        }
      } catch (_) {}
      done++;
      _setProgress(surah, done / tracks.length);
    }
    _clearProgress(surah);
    state = state.copyWith(downloaded: {...state.downloaded, surah});
    // "6 adet" sınırı: yeni sure en sonda → en ESKİ (.first) silinir.
    int? evicted;
    while (state.downloaded.length > _maxKept) {
      final oldest = state.downloaded.first;
      if (oldest == surah) break; // az önce indirileni asla silme
      await _removeFiles(oldest);
      state = state.copyWith(downloaded: {...state.downloaded}..remove(oldest));
      evicted = oldest;
    }
    _persist();
    return evicted;
  }

  /// İndirilmiş sureyi siler (UI'dan elle). Dosyaları temizler + listeden çıkarır.
  Future<void> remove(int surah) async {
    await _removeFiles(surah);
    state = state.copyWith(downloaded: {...state.downloaded}..remove(surah));
    _persist();
  }

  /// `<sure>_*.mp3` tüm ayet dosyalarını siler (track listesi gerekmez).
  Future<void> _removeFiles(int surah) async {
    if (_dir == null) return;
    try {
      final prefix = '${surah}_';
      await for (final e in _dir!.list()) {
        if (e is File && e.uri.pathSegments.last.startsWith(prefix)) {
          await e.delete();
        }
      }
    } catch (_) {}
  }

  void _setProgress(int surah, double p) =>
      state = state.copyWith(progress: {...state.progress, surah: p});

  void _clearProgress(int surah) =>
      state = state.copyWith(progress: {...state.progress}..remove(surah));

  void _persist() => ref
      .read(sharedPreferencesProvider)
      .setStringList(_prefsKey, state.downloaded.map((e) => '$e').toList());
}

final quranDownloadProvider =
    NotifierProvider<QuranDownloadController, QuranDownloadState>(
        QuranDownloadController.new);
