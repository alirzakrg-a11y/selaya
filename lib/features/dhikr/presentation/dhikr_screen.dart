import 'dart:convert';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../daily_tasks/data/daily_tasks_controller.dart';
import '../../daily_tasks/domain/daily_task.dart';

/// Stone/wood bead colours offered in the picker.
const _beadColors = [
  Color(0xFFE8E2D0), // white marble
  Color(0xFF7C97B5), // blue stone
  Color(0xFFB5482E), // red agate
  Color(0xFF2E2E38), // black onyx
  Color(0xFF4E7C59), // green jade
  Color(0xFF8A6A4A), // brown wood
  Color(0xFFD9B45B), // amber
];

const _ringCount = 33;

/// A unified zikir for the rotation — either a built-in preset or a custom one
/// the user added. (#9 custom dhikr + ready-list selection.)
class _Zikir {
  final String arabic;
  final String translit;
  final String meaning;
  final bool custom;
  final int count; // hedef zikir sayısı (0 = serbest)
  const _Zikir(this.arabic, this.translit, this.meaning,
      {this.custom = false, this.count = 0});

  Map<String, dynamic> toJson() =>
      {'ar': arabic, 'tl': translit, 'mn': meaning, 'ct': count};
  factory _Zikir.fromJson(Map<String, dynamic> j) => _Zikir(
        (j['ar'] ?? '').toString(),
        (j['tl'] ?? '').toString(),
        (j['mn'] ?? '').toString(),
        custom: true,
        count: (j['ct'] is num) ? (j['ct'] as num).toInt() : 0,
      );
}

class DhikrScreen extends ConsumerStatefulWidget {
  /// Optional ebced-zikir goal passed from Esmaül Hüsna: recite [zikirName]
  /// ([zikirArabic]) up to [targetCount] (the name's ebced value).
  final String? zikirArabic;
  final String? zikirName;
  final int? targetCount;

  /// Günlük görevden açıldıysa o görevin id'si (③). Hedefe ulaşınca o görev
  /// otomatik "yapıldı" işaretlenir. null = serbest/Esmâ açılışı.
  final String? taskId;
  const DhikrScreen(
      {super.key,
      this.zikirArabic,
      this.zikirName,
      this.targetCount,
      this.taskId});
  @override
  ConsumerState<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends ConsumerState<DhikrScreen> {
  int _count = 0;
  int _tur = 1;
  int _presetIndex = 0;
  int _bead = 0;
  int _goalCount = 0;
  int _tab = 1; // 0 = Zikirlerim (custom), 1 = Tümü (all)
  // ③ Serbest modda da görev işaretlensin: seçili zikrin Arapçası (build atar)
  // + bu oturumda zikir başına çekilen sayı. Bugünün görevlerinden Arapçası
  // eşleşen hedefe ulaşınca otomatik "yapıldı" işaretlenir (görevden açılmasa da).
  String _currentAr = '';
  final Map<String, int> _sessionTally = {};
  bool _sound = true;
  bool _vibrate = true;
  bool _hasVibrator = false;
  String _soundType = 'tahta'; // bkz. _sounds listesi
  List<_Zikir> _custom = [];
  final _player = AudioPlayer();

  bool get _goalMode => widget.targetCount != null;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _sound = prefs.getBool(PrefKeys.dhikrSound) ?? true;
    _vibrate = prefs.getBool(PrefKeys.dhikrVibration) ?? true;
    Vibration.hasVibrator().then((v) {
      if (mounted) _hasVibrator = v == true;
    });
    _soundType = prefs.getString(PrefKeys.dhikrSoundType) ?? 'tahta';
    _bead = prefs.getInt(PrefKeys.dhikrBead) ?? 0;
    _custom = _loadCustom(prefs.getString(PrefKeys.dhikrCustom));
    _preload();
  }

  static List<_Zikir> _loadCustom(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          _Zikir.fromJson((e as Map).cast<String, dynamic>())
      ];
    } catch (_) {
      return [];
    }
  }

  /// Seçilebilir zikirmatik tıkırtı sesleri — kullanıcı dener, beğendiğini tutar.
  /// İlk 5 yeni (ffmpeg ile özenle üretildi), son 2 klasik (eski).
  static const _sounds = [
    (id: 'tahta', label: 'dhikr.sndTahta', asset: 'assets/audio/dhikr_wood.wav'),
    (id: 'tiknet', label: 'dhikr.sndTiknet', asset: 'assets/audio/dhikr_click.wav'),
    (id: 'su', label: 'dhikr.sndSu', asset: 'assets/audio/dhikr_drop.wav'),
    (id: 'yumusak', label: 'dhikr.sndYumusak', asset: 'assets/audio/dhikr_soft.wav'),
    (id: 'derin', label: 'dhikr.sndDerin', asset: 'assets/audio/dhikr_knock.wav'),
    (id: 'boncuk', label: 'dhikr.soundBead', asset: 'assets/audio/bead_wood.wav'),
    (id: 'tik', label: 'dhikr.soundTick', asset: 'assets/audio/bead.wav'),
  ];

  /// Seçili tıkırtı sesinin asset yolu.
  String get _soundAsset {
    for (final s in _sounds) {
      if (s.id == _soundType) return s.asset;
    }
    return _sounds.first.asset;
  }

  Future<void> _preload() async {
    try {
      await _player.setAsset(_soundAsset);
    } catch (_) {}
  }

  Future<void> _setSoundType(String t) async {
    setState(() => _soundType = t);
    ref.read(sharedPreferencesProvider).setString(PrefKeys.dhikrSoundType, t);
    try {
      await _player.setAsset(_soundAsset);
      await _player.play(); // quick preview so the choice is audible
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String get _todayKey =>
      '${PrefKeys.dhikrTotalPrefix}${DateTime.now().toIso8601String().substring(0, 10)}';

  int get _todayTotal =>
      ref.read(sharedPreferencesProvider).getInt(_todayKey) ?? 0;

  Future<void> _playBead() async {
    if (!_sound) return;
    try {
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {}
  }

  void _increment() {
    _buzz(18, 110);
    _playBead();
    ref.read(sharedPreferencesProvider).setInt(_todayKey, _todayTotal + 1);
    setState(() {
      _count++;
      if (_count >= _ringCount) {
        _count = 0;
        _tur++;
        _buzz(45, 255);
      }
      if (_goalMode && _goalCount < widget.targetCount!) {
        _goalCount++;
        if (_goalCount == widget.targetCount) {
          _buzz(60, 255);
          _markTaskDone();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('dhikr.goalDone'.tr())));
            }
          });
        }
      }
      // ③ Görevden açılmasa bile: seçili zikir bugünün bir zikir göreviyle
      // eşleşiyorsa ve oturum sayacı hedefe ulaştıysa görevi işaretle.
      if (_currentAr.isNotEmpty) {
        final n = (_sessionTally[_currentAr] ?? 0) + 1;
        _sessionTally[_currentAr] = n;
        _autoMarkMatchingTask(_currentAr, n);
      }
    });
  }

  /// Bugünün görevlerinde Arapçası [ar] olan zikir görevi varsa ve [n] hedefi
  /// karşıladıysa "yapıldı" işaretle (idempotent — işaretliyse dokunma).
  void _autoMarkMatchingTask(String ar, int n) {
    for (final t in dailyTasksFor(DateTime.now())) {
      if (t.zikirAr == ar && n >= (t.zikirTarget ?? _ringCount)) {
        final tasks = ref.read(dailyTasksProvider.notifier);
        if (!tasks.isDoneToday(t.id)) {
          tasks.toggleToday(t.id);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('dhikr.goalDone'.tr())));
            }
          });
        }
      }
    }
  }

  /// ③ Bu ekran bir günlük görevden açıldıysa (taskId != null) ve hedefe yeni
  /// ulaşıldıysa o görevi otomatik "yapıldı" işaretle. Idempotent: zaten
  /// işaretliyse hiç dokunma (toggle olduğu için aksi halde geri alır).
  void _markTaskDone() {
    final id = widget.taskId;
    if (id == null || id.isEmpty) return;
    final tasks = ref.read(dailyTasksProvider.notifier);
    if (tasks.isDoneToday(id)) return;
    tasks.toggleToday(id);
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    setState(() {
      _count = 0;
      _tur = 1;
    });
  }

  void _setTab(int t) => setState(() {
        _tab = t;
        _presetIndex = 0;
        _count = 0;
      });

  void _toggleSound() {
    setState(() => _sound = !_sound);
    ref.read(sharedPreferencesProvider).setBool(PrefKeys.dhikrSound, _sound);
  }

  /// Gerçek titreşim — doğrudan VIBRATE motoru; sistemin "dokunma titreşimi"
  /// ayarı kapalı olsa da titrer (Samsung'da HapticFeedback çoğu kez sessizdi).
  void _buzz(int ms, int amp) {
    if (!_vibrate) return;
    if (_hasVibrator) {
      Vibration.vibrate(duration: ms, amplitude: amp);
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _toggleVibration() {
    setState(() => _vibrate = !_vibrate);
    ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.dhikrVibration, _vibrate);
    if (_vibrate) _buzz(35, 200);
  }

  void _setBead(int i) {
    setState(() => _bead = i);
    ref.read(sharedPreferencesProvider).setInt(PrefKeys.dhikrBead, i);
  }

  void _saveCustom() {
    ref.read(sharedPreferencesProvider).setString(PrefKeys.dhikrCustom,
        jsonEncode([for (final z in _custom) z.toJson()]));
  }

  void _addCustom(String translit, String arabic, String meaning, int count) {
    setState(() {
      _custom = [
        ..._custom,
        _Zikir(arabic.trim(), translit.trim(), meaning.trim(),
            custom: true, count: count),
      ];
      _tab = 0; // jump to "Zikirlerim" so the new one is visible
      _presetIndex = _custom.length - 1;
      _count = 0;
    });
    _saveCustom();
  }

  void _removeCustom(_Zikir z) {
    setState(() {
      _custom = _custom.where((x) => x != z).toList();
      _presetIndex = 0;
      _count = 0;
    });
    _saveCustom();
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final presets =
        ref.watch(dhikrPresetsProvider).value ?? const <DhikrPreset>[];
    final allZikirs = <_Zikir>[
      for (final p in presets)
        _Zikir(p.arabic, p.transliteration, p.meaning(lang)),
      ..._custom,
    ];
    final list = _tab == 0 ? _custom : allZikirs;

    final _Zikir? z = _goalMode
        ? _Zikir(widget.zikirArabic ?? '', widget.zikirName ?? '', '')
        : (list.isEmpty ? null : list[_presetIndex % list.length]);
    _currentAr = z?.arabic ?? ''; // ③ _increment görev eşleştirmesi için
    final total = _goalMode ? (widget.targetCount ?? _ringCount) : _ringCount;
    final shown = _goalMode ? _goalCount : _count;

    return SelayaScaffold(
      title: 'dhikr.title'.tr(),
      showBack: true,
      actions: [_todayAction()],
      body: Column(
        children: [
          if (!_goalMode) _tabs(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
            child: _zikirCard(z, list, lang),
          ),
          const Gap.sm(),
          _beadRow(),
          // Counter + falling tesbih string + action buttons. Tap anywhere here
          // to count.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: z == null ? null : _increment,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: CustomPaint(
                            painter: _BeadRingPainter(
                              lit: _litBeads(shown),
                              total: _ringCount,
                              beadLit: _beadColors[_bead],
                              beadDim: context.colors.surfaceAlt,
                              glow: context.colors.gold,
                              string: context.colors.border,
                            ),
                            child: Center(child: _counter(shown, total)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _buttons(list, lang),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lit-bead count for the ring (out of [_ringCount], looping each tur).
  int _litBeads(int shown) =>
      shown == 0 ? 0 : ((shown - 1) % _ringCount) + 1;

  Widget _tabs() {
    final c = context.colors;
    Widget tab(int i, String label) {
      final sel = _tab == i;
      return Expanded(
        child: InkWell(
          onTap: () => _setTab(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: sel ? c.gold : c.textTertiary,
                          fontWeight:
                              sel ? FontWeight.w800 : FontWeight.w500,
                        )),
                const SizedBox(height: 8),
                Container(
                  height: 3,
                  width: 48,
                  decoration: BoxDecoration(
                    color: sel ? c.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(children: [
        tab(0, 'dhikr.tabMine'.tr()),
        tab(1, 'dhikr.tabAll'.tr()),
      ]),
    );
  }

  Widget _zikirCard(_Zikir? z, List<_Zikir> list, String lang) {
    final c = context.colors;
    if (z == null) {
      // Empty "Zikirlerim" tab — invite to add one.
      return SelayaCard(
        onTap: _showAddCustomDialog,
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: c.gold),
            const Gap.md(),
            Expanded(
              child: Text('dhikr.empty'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.textSecondary)),
            ),
          ],
        ),
      );
    }
    return SelayaCard(
      gradient: LinearGradient(
        colors: [c.gold.withValues(alpha: 0.16), c.surfaceAlt],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      onTap: _goalMode ? null : () => _showZikirPicker(list, lang),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                if (z.arabic.isNotEmpty)
                  Text(z.arabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.arabic(fontSize: 28, color: c.gold)),
                const Gap.xs(),
                Text(z.translit,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (_goalMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        'dhikr.ebcedZikir'.tr(args: ['${widget.targetCount}']),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.gold, fontWeight: FontWeight.w600)),
                  )
                else if (z.meaning.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(z.meaning,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: c.textSecondary)),
                  ),
              ],
            ),
          ),
          if (!_goalMode)
            Icon(Icons.chevron_right_rounded, color: c.gold),
        ],
      ),
    );
  }

  Widget _beadRow() {
    final c = context.colors;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        itemCount: _beadColors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final sel = i == _bead;
          return Center(
            child: GestureDetector(
              onTap: () => _setBead(i),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.4),
                    colors: [
                      Color.lerp(_beadColors[i], Colors.white, 0.5)!,
                      _beadColors[i],
                    ],
                  ),
                  border: Border.all(
                      color: sel ? c.gold : c.border, width: sel ? 2.5 : 1),
                ),
                child: sel
                    ? Icon(Icons.check_rounded,
                        size: 18,
                        color: ThemeData.estimateBrightnessForColor(
                                    _beadColors[i]) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black54)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _counter(int shown, int total) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$shown',
                style: AppTypography.countdown(c.gold, fontSize: 56)),
            Text(' / $total',
                style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        if (!_goalMode)
          Text('dhikr.round'.tr(args: ['$_tur']),
              style: TextStyle(
                  color: c.gold, fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }

  Widget _buttons(List<_Zikir> list, String lang) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleBtn(Icons.add_rounded, _showAddCustomDialog),
        const Gap.base(),
        _circleBtn(AppIcons.settings, _showSettings),
        const Gap.base(),
        _circleBtn(Icons.edit_rounded,
            _goalMode ? _reset : () => _showZikirPicker(list, lang)),
      ],
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      elevation: 1.5,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: c.gold, size: 22),
        ),
      ),
    );
  }

  /// Bugünün toplam zikir sayısı için app bar rozeti — dokununca istatistik.
  Widget _todayAction() {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Center(
        child: GestureDetector(
          onTap: _showStats,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.gold.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.today_rounded, size: 14, color: c.gold),
                const Gap.xxs(),
                Text('$_todayTotal',
                    style: TextStyle(
                        color: c.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Son 7 günün zikir toplamları (cihazda saklanan günlük sayaçlardan okunur).
  List<(String, int, bool)> _last7() {
    final prefs = ref.read(sharedPreferencesProvider);
    final tr = context.langCode == 'tr';
    const wdTr = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'];
    const wdEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final out = <(String, int, bool)>[];
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${PrefKeys.dhikrTotalPrefix}${d.toIso8601String().substring(0, 10)}';
      final label = (tr ? wdTr : wdEn)[d.weekday - 1];
      out.add((label, prefs.getInt(key) ?? 0, i == 0));
    }
    return out;
  }

  /// Günlük + son 7 günlük zikir istatistiği sayfası (önceden gizliydi).
  void _showStats() {
    final c = context.colors;
    final data = _last7();
    final maxV = data.fold(0, (a, e) => e.$2 > a ? e.$2 : a);
    final weekSum = data.fold(0, (a, e) => a + e.$2);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.insights_rounded, color: c.gold),
                const Gap.sm(),
                Text('xt.dhStatsTitle'.tr(),
                    style: Theme.of(context).textTheme.titleMedium),
              ]),
              const Gap.lg(),
              Text('xt.dhToday'.tr(),
                  style: TextStyle(
                      color: c.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1)),
              const Gap.xxs(),
              Text('$_todayTotal',
                  style: AppTypography.countdown(c.gold, fontSize: 44)),
              const Gap.lg(),
              Text('xt.dhLast7Days'.tr(args: [weekSum.toString()]),
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: c.textSecondary)),
              const Gap.sm(),
              SizedBox(
                height: 96,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (label, v, isToday) in data)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('$v',
                                style: TextStyle(
                                    color: c.textTertiary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                            const Gap.xxs(),
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              height: maxV == 0 ? 3 : (3 + 60 * v / maxV),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? c.gold
                                    : c.gold.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const Gap.xs(),
                            Text(label,
                                style: TextStyle(
                                    color: isToday ? c.gold : c.textTertiary,
                                    fontSize: 11,
                                    fontWeight: isToday
                                        ? FontWeight.w800
                                        : FontWeight.w500)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Gap.sm(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sheets & dialogs ───────────────────────────────────────────────────
  void _showSettings() {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                secondary: Icon(_sound ? AppIcons.volumeHigh : AppIcons.volumeOff,
                    color: c.gold),
                title: Text('dhikr.sound'.tr()),
                value: _sound,
                activeThumbColor: c.gold,
                onChanged: (_) {
                  _toggleSound();
                  setSheet(() {});
                },
              ),
              SwitchListTile(
                secondary: Icon(
                    _vibrate
                        ? Icons.vibration_rounded
                        : Icons.smartphone_rounded,
                    color: _vibrate ? c.gold : c.textTertiary),
                title: Text('xt.dhVibration'.tr()),
                value: _vibrate,
                activeThumbColor: c.gold,
                onChanged: (_) {
                  _toggleVibration();
                  setSheet(() {});
                },
              ),
              if (_sound)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('dhikr.soundType'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      // Dokununca o sesi hemen çalar (ön-dinleme) → beğendiğini seç.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in _sounds)
                            ChoiceChip(
                              label: Text(s.label.tr()),
                              selected: _soundType == s.id,
                              onSelected: (_) {
                                _setSoundType(s.id);
                                setSheet(() {});
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ListTile(
                leading: Icon(AppIcons.reset, color: c.gold),
                title: Text('dhikr.reset'.tr()),
                onTap: () {
                  _reset();
                  Navigator.of(context).pop();
                },
              ),
              const Gap.sm(),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom sheet to pick any zikir (built-in + custom) or add a custom one.
  void _showZikirPicker(List<_Zikir> all, String lang) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, scroll) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.base,
                    AppSpacing.sm, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('dhikr.chooseTitle'.tr(),
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showAddCustomDialog();
                      },
                      icon: Icon(Icons.add_rounded, color: c.gold, size: 20),
                      label: Text('dhikr.addCustom'.tr(),
                          style: TextStyle(
                              color: c.gold, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: all.length,
                  itemBuilder: (_, i) {
                    final z = all[i];
                    final sel = all.isNotEmpty && i == _presetIndex % all.length;
                    return ListTile(
                      selected: sel,
                      selectedTileColor: c.gold.withValues(alpha: 0.08),
                      title: Text(z.translit,
                          style: TextStyle(
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500)),
                      subtitle: (z.meaning.isEmpty && z.count == 0)
                          ? null
                          : Text(
                              [
                                if (z.meaning.isNotEmpty) z.meaning,
                                if (z.count > 0) '🎯 ${z.count}',
                              ].join('   ·   '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      trailing: z.custom
                          ? IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: c.danger),
                              onPressed: () {
                                _removeCustom(z);
                                Navigator.of(context).pop();
                              },
                            )
                          : (sel
                              ? Icon(Icons.check_rounded, color: c.gold)
                              : null),
                      onTap: () {
                        setState(() {
                          _presetIndex = i;
                          _count = 0;
                        });
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dialog to add a custom zikir (transliteration required; arabic + meaning
  /// optional).
  void _showAddCustomDialog() {
    final tl = TextEditingController();
    final ar = TextEditingController();
    final mn = TextEditingController();
    final ct = TextEditingController();
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('dhikr.addCustom'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tl,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    InputDecoration(labelText: 'dhikr.fieldName'.tr()),
              ),
              const Gap.sm(),
              TextField(
                controller: ar,
                decoration:
                    InputDecoration(labelText: 'dhikr.fieldArabic'.tr()),
              ),
              const Gap.sm(),
              TextField(
                controller: mn,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    InputDecoration(labelText: 'dhikr.fieldMeaning'.tr()),
              ),
              const Gap.sm(),
              TextField(
                controller: ct,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'xt.dhCountFieldLabel'.tr()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              if (tl.text.trim().isEmpty) return;
              _addCustom(tl.text, ar.text, mn.text,
                  int.tryParse(ct.text.trim()) ?? 0);
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: c.onGold),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }
}

/// A round tesbih: [total] beads in a ring, filling clockwise from the top as
/// the count rises. Lit beads use the chosen colour (the latest one glows); the
/// rest stay dim. The count sits in the centre.
class _BeadRingPainter extends CustomPainter {
  final int lit;
  final int total;
  final Color beadLit;
  final Color beadDim;
  final Color glow;
  final Color string;
  _BeadRingPainter({
    required this.lit,
    required this.total,
    required this.beadLit,
    required this.beadDim,
    required this.glow,
    required this.string,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final beadR = size.shortestSide * 0.05;
    final radius = size.shortestSide / 2 - beadR - 4;

    // Faint ring the beads sit on.
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = string
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    for (var i = 0; i < total; i++) {
      final ang = -pi / 2 + (2 * pi * i / total);
      final pos = center + Offset(cos(ang), sin(ang)) * radius;
      final isLit = i < lit;
      final base = isLit ? beadLit : beadDim;
      if (i == lit - 1 && lit > 0) {
        canvas.drawCircle(
            pos,
            beadR * 1.7,
            Paint()
              ..color = glow.withValues(alpha: 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      }
      final shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: [
          Color.lerp(base, Colors.white, 0.55)!,
          base,
          Color.lerp(base, Colors.black, 0.4)!,
        ],
        stops: const [0, 0.5, 1],
      ).createShader(Rect.fromCircle(center: pos, radius: beadR));
      canvas.drawCircle(pos, beadR, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(_BeadRingPainter old) =>
      old.lit != lit || old.beadLit != beadLit || old.total != total;
}
