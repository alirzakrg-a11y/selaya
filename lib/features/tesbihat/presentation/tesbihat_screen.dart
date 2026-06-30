import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';

/// Tek bir tesbihat adımı: Arapça + okunuş + anlam + hedef tekrar sayısı.
class _Zikr {
  final String arabic;
  final String reading;
  final String meaningTr;
  final String meaningEn;
  final int target;
  const _Zikr(
    this.arabic,
    this.reading,
    this.meaningTr,
    this.meaningEn,
    this.target,
  );
}

/// Namaz sonrası tesbihat (Diyanet tertibi): selâmdan sonra istiğfar + esenlik
/// duâsı, ardından 33 Sübhânallah + 33 Elhamdülillah + 33 Allâhüekber + kelime-i
/// tevhîd. Kısa metinler Müslim/standart kaynaklıdır. (Âyetü'l-Kürsî tam metni
/// ayrı/kaydırılabilir kart gerektirdiğinden ileride eklenecek.)
const _steps = <_Zikr>[
  _Zikr(
    'أَسْتَغْفِرُ اللّٰهَ',
    'Estağfirullah',
    'Allah’tan bağışlanma dilerim.',
    'I seek forgiveness from Allah.',
    3,
  ),
  _Zikr(
    'اَللّٰهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ',
    'Allâhümme ente’s-selâmü ve minke’s-selâm, tebârekte yâ ze’l-celâli ve’l-ikrâm',
    'Allah’ım! Selâm sensin, esenlik yalnız sendendir. Ey celâl ve ikram sahibi, sen mübareksin.',
    'O Allah, You are Peace and from You is peace. Blessed are You, O Owner of Majesty and Honour.',
    1,
  ),
  _Zikr(
    'سُبْحَانَ اللّٰهِ',
    'Sübhânallah',
    'Allah’ı her türlü noksanlıktan tenzih ederim.',
    'Glory be to Allah.',
    33,
  ),
  _Zikr(
    'اَلْحَمْدُ لِلّٰهِ',
    'Elhamdülillah',
    'Hamd, âlemlerin Rabbi olan Allah’a mahsustur.',
    'All praise is due to Allah.',
    33,
  ),
  _Zikr(
    'اَللّٰهُ اَكْبَرُ',
    'Allâhüekber',
    'Allah en büyüktür.',
    'Allah is the Greatest.',
    33,
  ),
  _Zikr(
    'لَا إِلٰهَ إِلَّا اللّٰهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
    'Lâ ilâhe illallâhü vahdehû lâ şerîke leh, lehü’l-mülkü ve lehü’l-hamdü ve hüve alâ külli şey’in kadîr',
    'Allah’tan başka ilah yoktur; O birdir, ortağı yoktur. Mülk O’nun, hamd O’nadır ve O her şeye kâdirdir.',
    'There is no god but Allah, alone, without partner. His is the dominion and His the praise, and He has power over all things.',
    1,
  ),
];

class TesbihatScreen extends ConsumerStatefulWidget {
  const TesbihatScreen({super.key});
  @override
  ConsumerState<TesbihatScreen> createState() => _TesbihatScreenState();
}

class _TesbihatScreenState extends ConsumerState<TesbihatScreen> {
  int _step = 0;
  int _count = 0;
  bool _done = false;
  bool _sound = true;
  bool _vibrate = true;
  bool _hasVibrator = false;
  // Tamamlanma anındaki artık (ritim) dokunuşlar "Yeniden başla"yı tetiklemesin.
  bool _restartLocked = false;
  Timer? _unlockTimer;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _sound = prefs.getBool(PrefKeys.dhikrSound) ?? true;
    _vibrate = prefs.getBool(PrefKeys.dhikrVibration) ?? true;
    Vibration.hasVibrator().then((v) {
      if (mounted) _hasVibrator = v == true;
    });
    _preload();
  }

  Future<void> _preload() async {
    try {
      await _player.setAsset('assets/audio/dhikr_wood.wav');
    } catch (_) {}
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  /// Gerçek titreşim — doğrudan VIBRATE motoru; HapticFeedback'in aksine sistemin
  /// "dokunma titreşimi" ayarı kapalı olsa da titrer (Samsung'da çoğu kez kapalı).
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

  /// Her sayımda kısa tıkırtı (zikirmatikle aynı ses; aç/kapat kalıcı).
  Future<void> _playTick() async {
    if (!_sound) return;
    try {
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {}
  }

  void _toggleSound() {
    setState(() => _sound = !_sound);
    ref.read(sharedPreferencesProvider).setBool(PrefKeys.dhikrSound, _sound);
  }

  void _reset() => setState(() {
    _step = 0;
    _count = 0;
    _done = false;
  });

  void _tap() {
    if (_done) return;
    _playTick();
    final z = _steps[_step];
    if (_count + 1 >= z.target) {
      // Adım tamamlandı → güçlü titreşim + sıradaki adım (veya bitti).
      _buzz(45, 255);
      if (_step + 1 >= _steps.length) {
        setState(() {
          _count = z.target;
          _done = true;
          _restartLocked = true;
        });
        // ~1 sn boyunca "Yeniden başla" kilitli kalsın ki bitişten sonraki
        // istemsiz dokunuşlar tesbihatı hemen sıfırlamasın.
        _unlockTimer?.cancel();
        _unlockTimer = Timer(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _restartLocked = false);
        });
      } else {
        setState(() {
          _step++;
          _count = 0;
        });
      }
    } else {
      _buzz(18, 110);
      setState(() => _count++);
    }
  }

  /// Namaz tesbihatının ne olduğunu + faziletini (hadis) anlatan bilgi sayfası.
  void _showInfo() {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          maxChildSize: 0.9,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(children: [
                Icon(Icons.auto_awesome_rounded, color: c.gold),
                const Gap.sm(),
                Expanded(
                  child: Text('xt.tsInfoTitle'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ]),
              const Gap.md(),
              Text(
                'xt.tsInfoBody'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.textSecondary, height: 1.5),
              ),
              const Gap.lg(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: c.gold.withValues(alpha: 0.08),
                  borderRadius: AppRadius.rLg,
                  border: Border.all(color: c.gold.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'xt.tsHadith'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.55, fontStyle: FontStyle.italic),
                    ),
                    const Gap.sm(),
                    Text('— Müslim, Mesâcid 146',
                        style: TextStyle(
                            color: c.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5)),
                  ],
                ),
              ),
              const Gap.md(),
              Row(children: [
                Icon(Icons.menu_book_rounded, size: 16, color: c.gold),
                const Gap.sm(),
                Expanded(
                  child: Text(
                    'xt.tsSource'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textTertiary),
                  ),
                ),
              ]),
              const Gap.sm(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    return SelayaScaffold(
      title: 'tesbihat.title'.tr(),
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'xt.tsSound'.tr(),
          icon: Icon(
              _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: context.colors.gold),
          onPressed: _toggleSound,
        ),
        IconButton(
          tooltip: 'xt.tsVibration'.tr(),
          icon: Icon(
              _vibrate
                  ? Icons.vibration_rounded
                  : Icons.smartphone_rounded,
              color:
                  _vibrate ? context.colors.gold : context.colors.textTertiary),
          onPressed: _toggleVibration,
        ),
        IconButton(
          tooltip: 'xt.tsInfo'.tr(),
          icon: Icon(Icons.info_outline_rounded, color: context.colors.gold),
          onPressed: _showInfo,
        ),
        IconButton(
          tooltip: 'common.reset'.tr(),
          icon: Icon(Icons.refresh_rounded, color: context.colors.gold),
          onPressed: _reset,
        ),
      ],
      body: _done ? _completed(context, tr) : _counter(context, tr),
    );
  }

  Widget _counter(BuildContext context, bool tr) {
    final c = context.colors;
    final z = _steps[_step];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.sm,
          AppSpacing.base,
          AppSpacing.xl,
        ),
        child: Column(
          children: [
            // Çalışılan zikir kartı: Arapça + okunuş + anlam.
            SelayaCard(
              gradient: LinearGradient(
                colors: [c.gold.withValues(alpha: 0.18), c.surfaceAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      z.arabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.arabic(fontSize: 30, color: c.gold),
                    ),
                  ),
                  const Gap.sm(),
                  Text(
                    z.reading,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: c.textPrimary,
                    ),
                  ),
                  const Gap.xs(),
                  Text(
                    tr ? z.meaningTr : z.meaningEn,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Büyük sayaç halkası — ekranın her yerine dokununca artar.
            SizedBox(
              width: 210,
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: CircularProgressIndicator(
                      value: _count / z.target,
                      strokeWidth: 11,
                      backgroundColor: c.border,
                      valueColor: AlwaysStoppedAnimation(c.gold),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_count',
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w800,
                          color: c.gold,
                        ),
                      ),
                      Text(
                        '/ ${z.target}',
                        style: TextStyle(color: c.textSecondary, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap.md(),
            Text(
              'xt.tsTapToCount'.tr(),
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
            const Spacer(),
            // Adım göstergesi (4 nokta) + "x / 4".
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _step ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i < _step
                          ? c.gold
                          : (i == _step ? c.gold : c.border),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
            const Gap.sm(),
            Text(
              'xt.tsStepIndicator'.tr(
                  args: ['${_step + 1}', '${_steps.length}']),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completed(BuildContext context, bool tr) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 72, color: c.gold),
            const Gap.lg(),
            Text(
              'xt.tsCompleteTitle'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Gap.sm(),
            Text(
              'xt.tsCompleteBody'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
                height: 1.5,
              ),
            ),
            const Gap.xl(),
            FilledButton.icon(
              onPressed: () {
                // Bitişten hemen sonraki istemsiz dokunuşları yok say.
                if (_restartLocked) return;
                _reset();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('xt.tsRestart'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: c.onGold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
