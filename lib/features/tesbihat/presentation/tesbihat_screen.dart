import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

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

/// Namaz sonrası tesbihat: 33 Sübhânallah + 33 Elhamdülillah + 33 Allâhüekber
/// + kelime-i tevhîd (toplam 100). Metinler standart/doğrulanmış kısa zikirlerdir.
const _steps = <_Zikr>[
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
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _sound =
        ref.read(sharedPreferencesProvider).getBool(PrefKeys.dhikrSound) ?? true;
    _preload();
  }

  Future<void> _preload() async {
    try {
      await _player.setAsset('assets/audio/dhikr_wood.wav');
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
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
      HapticFeedback.mediumImpact();
      if (_step + 1 >= _steps.length) {
        setState(() {
          _count = z.target;
          _done = true;
        });
      } else {
        setState(() {
          _step++;
          _count = 0;
        });
      }
    } else {
      HapticFeedback.lightImpact();
      setState(() => _count++);
    }
  }

  /// Namaz tesbihatının ne olduğunu + faziletini (hadis) anlatan bilgi sayfası.
  void _showInfo() {
    final c = context.colors;
    final tr = context.langCode == 'tr';
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
                  child: Text(tr ? 'Namaz Tesbihatı' : 'Post-Prayer Tasbihat',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ]),
              const Gap.md(),
              Text(
                tr
                    ? 'Her farz namazdan sonra 33 defa “Sübhânallah”, 33 defa “Elhamdülillah” ve 33 defa “Allâhüekber” denir; böylece doksan dokuza ulaşılır. Yüzü tamamlamak için kelime-i tevhîd okunur.'
                    : 'After each obligatory prayer one says 33× “Subhanallah”, 33× “Alhamdulillah” and 33× “Allahu akbar”, reaching ninety-nine; the hundredth is completed with the tahlil (kalima of monotheism).',
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
                      tr
                          ? '“Her namazın ardından kim otuz üç defa Sübhânallah, otuz üç defa Elhamdülillah ve otuz üç defa Allâhüekber der; böylece doksan dokuz olur. Yüzü tamamlamak için de ‘Lâ ilâhe illallâhü vahdehû lâ şerîke leh, lehü’l-mülkü ve lehü’l-hamdü ve hüve alâ külli şey’in kadîr’ derse, denizin köpüğü kadar bile olsa günahları bağışlanır.”'
                          : '“Whoever, after every prayer, glorifies Allah 33 times, praises Him 33 times and magnifies Him 33 times — that is ninety-nine — and completes the hundred with ‘La ilaha illallahu wahdahu la sharika lah…’, his sins are forgiven even if they were like the foam of the sea.”',
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
                    tr
                        ? 'Kaynak: Diyanet İşleri Başkanlığı esas alınmıştır.'
                        : 'Source: based on the Diyanet (Presidency of Religious Affairs).',
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
          tooltip: tr ? 'Ses' : 'Sound',
          icon: Icon(
              _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: context.colors.gold),
          onPressed: _toggleSound,
        ),
        IconButton(
          tooltip: tr ? 'Bilgi' : 'Info',
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
              tr ? 'Saymak için ekrana dokun' : 'Tap anywhere to count',
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
              '${tr ? 'Adım' : 'Step'} ${_step + 1} / ${_steps.length}',
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
              tr ? 'Tesbihat tamamlandı' : 'Tasbihat complete',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Gap.sm(),
            Text(
              tr
                  ? 'Allah ibadetini kabul etsin. 33 + 33 + 33 + tevhîd ile tesbihatını tamamladın.'
                  : 'May Allah accept your worship. You completed 33 + 33 + 33 + tahlil.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
                height: 1.5,
              ),
            ),
            const Gap.xl(),
            FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(tr ? 'Yeniden başla' : 'Start again'),
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
