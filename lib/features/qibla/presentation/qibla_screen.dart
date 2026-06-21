import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/services/declination_service.dart';
import '../../../core/services/qibla_sensor_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../prayer_times/data/prayer_repository.dart';

/// Compass accent themes the user can pick from.
const _qiblaThemes = [
  Color(0xFFE0B250), // gold (default)
  Color(0xFF4E9C6B), // emerald
  Color(0xFF5B8DEF), // blue
  Color(0xFF9B6DD6), // purple
  Color(0xFF2BB3A3), // teal
  Color(0xFFE07A5F), // terracotta
  Color(0xFFD94F70), // rose
  Color(0xFF5BC0DE), // cyan
];

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});
  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  int _theme = 0;
  bool _haptic = true;
  bool _wasAligned = false;
  // Declination depends only on location → memoise it per city so it isn't
  // recomputed on every compass tick.
  double _declination = 0;
  String? _declCity;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _theme = prefs.getInt(PrefKeys.qiblaTheme) ?? 0;
    _haptic = prefs.getBool(PrefKeys.qiblaHaptic) ?? true;
  }

  void _setTheme(int i) {
    setState(() => _theme = i);
    ref.read(sharedPreferencesProvider).setInt(PrefKeys.qiblaTheme, i);
  }

  void _toggleHaptic() {
    setState(() => _haptic = !_haptic);
    ref.read(sharedPreferencesProvider).setBool(PrefKeys.qiblaHaptic, _haptic);
    if (_haptic) _buzz(80);
  }

  /// Gerçek titreşim — VIBRATE izniyle motoru doğrudan çalıştırır; sistemin
  /// "dokunma titreşimi" ayarı kapalı olsa bile titrer (HapticFeedback ona
  /// bağlıydı, Samsung'da çoğu kez kapalı → hiç titremiyordu).
  Future<void> _buzz(int ms) async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: ms, amplitude: 255);
        return;
      }
    } catch (_) {}
    await HapticFeedback.heavyImpact();
  }

  String _dirLabel(double bearing) =>
      'qibla.dir${compassDirectionKey(bearing)}'.tr();

  void _share(double bearing, double dist) {
    SharePlus.instance.share(ShareParams(
        text: 'qibla.shareText'.tr(
            args: ['${bearing.round()}', _dirLabel(bearing), '${dist.round()}'])));
  }

  /// Pusulanın doğru kullanımı + kalibrasyon + manyetik/gerçek kuzey bilgisi.
  void _showInfo() {
    final c = context.colors;
    final tr = context.langCode == 'tr';
    final tips = tr
        ? const [
            'Telefonu yere paralel (düz) tutup yavaşça döndürün; üstteki ok Kâbe simgesiyle çakıştığında kıbleye dönüksünüz.',
            'Metal eşya, mıknatıs, hoparlör ve elektronik cihazlardan uzak, mümkünse açık bir yerde kullanın.',
            'Doğruluk düştüğünde telefonu havada 8 (sekiz) çizerek pusulayı kalibre edin.',
            'Pusula manyetik kuzeyi gösterir; uygulama bulunduğunuz yerin manyetik sapmasını (declination) hesaba katarak gerçek kıble yönüne göre düzeltir.',
            'Pusulaya güvenemediğinizde gündüz aşağıdaki “Güneşle Kıble” yöntemini kullanabilirsiniz.',
          ]
        : const [
            'Hold the phone flat (parallel to the ground) and turn slowly; you face the qibla when the top arrow meets the Kaaba marker.',
            'Use it away from metal, magnets, speakers and electronics — ideally outdoors.',
            'If accuracy drops, calibrate by moving the phone in a figure-8 in the air.',
            'The compass shows magnetic north; the app corrects for your local magnetic declination to point to the true qibla.',
            'When the compass is unreliable, use the “Qibla by Sun” method below during daytime.',
          ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(children: [
                Icon(Icons.explore_rounded, color: c.gold),
                const Gap.sm(),
                Expanded(
                  child: Text(
                      tr
                          ? 'Kıble Pusulası Nasıl Kullanılır?'
                          : 'Using the Qibla Compass',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ]),
              const Gap.lg(),
              for (var i = 0; i < tips.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.gold.withValues(alpha: 0.14)),
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: c.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                    const Gap.md(),
                    Expanded(
                      child: Text(tips[i],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: c.textSecondary, height: 1.45)),
                    ),
                  ],
                ),
                const Gap.md(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(selectedCityProvider).value;
    final reading = ref.watch(compassReadingProvider).value;
    final heading = reading?.heading;
    final accuracy = reading?.accuracy;
    final supported = ref.read(qiblaSensorServiceProvider).isSupported;
    final bearing = city == null ? 148.0 : qiblaBearing(city.coordinates);
    final dist = city == null ? 0.0 : distanceKm(city.coordinates, kaaba);
    final c = context.colors;
    final themeColor = _qiblaThemes[_theme % _qiblaThemes.length];

    // Correct the (true-north) qibla bearing to magnetic north so the needle
    // lines up with the magnetic compass sensor. Memoised per city.
    if (city != null && city.id != _declCity) {
      _declCity = city.id;
      _declination = magneticDeclination(city.coordinates);
    }
    final magneticBearing = (bearing - _declination) % 360;

    // Signed smallest angle from current heading to qibla (+ = turn right/cw).
    double? delta;
    if (heading != null) {
      delta = ((magneticBearing - heading + 540) % 360) - 180;
    }
    final aligned = delta != null && delta.abs() < 6;

    // Vibrate once each time we enter the aligned state (real motor buzz).
    if (aligned && !_wasAligned && _haptic) _buzz(350);
    _wasAligned = aligned;

    final lowAccuracy = accuracy != null && accuracy > 25;

    return SelayaScaffold(
      title: 'qibla.title'.tr(),
      showBack: Navigator.of(context).canPop(),
      actions: [
        IconButton(
          tooltip: 'qibla.haptic'.tr(),
          icon: Icon(
              _haptic ? Icons.vibration_rounded : Icons.smartphone_rounded,
              color: _haptic ? themeColor : c.textTertiary),
          onPressed: _toggleHaptic,
        ),
        IconButton(
          tooltip: context.langCode == 'tr' ? 'Nasıl kullanılır?' : 'How to use',
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: _showInfo,
        ),
        IconButton(
          tooltip: 'common.share'.tr(),
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: city == null ? null : () => _share(bearing, dist),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          const Gap.md(),
          Text('qibla.direction'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const Gap.xs(),
          Text('${bearing.round()}°',
              textAlign: TextAlign.center,
              style: AppTypography.countdown(themeColor, fontSize: 40)),
          Text(_dirLabel(bearing),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: c.textSecondary)),
          const Gap.md(),
          _TurnGuide(heading: heading, delta: delta, aligned: aligned),
          if (heading != null) ...[
            const Gap.sm(),
            Center(child: _AccuracyChip(accuracy: accuracy)),
          ],
          const Gap.md(),
          Center(
            child: _Compass(
                heading: heading ?? 0,
                bearing: magneticBearing,
                aligned: aligned,
                themeColor: themeColor),
          ),
          const Gap.lg(),
          _ThemePicker(selected: _theme, onPick: _setTheme),
          const Gap.lg(),
          if (!supported || lowAccuracy)
            Padding(
              padding: AppSpacing.screen,
              child: _CalibrationBanner(supported: supported),
            ),
          Padding(
            padding: AppSpacing.screen,
            child: SelayaCard(
              child: Row(
                children: [
                  Icon(aligned ? AppIcons.checkCircle : AppIcons.qibla,
                      color: aligned ? c.success : themeColor),
                  const Gap.md(),
                  Expanded(
                    child: Text(
                      heading == null
                          ? 'qibla.pointDevice'.tr()
                          : (aligned
                              ? 'qibla.aligned'.tr()
                              : 'qibla.calibrate'.tr()),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (city != null)
                    Text('${dist.round()} km',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: c.textTertiary)),
                ],
              ),
            ),
          ),
          if (city != null) ...[
            const Gap.md(),
            Padding(
              padding: AppSpacing.screen,
              child: _DetailsCard(
                city: city.name(context.langCode),
                coords: city.coordinates,
                trueBearing: bearing,
                magneticBearing: magneticBearing,
                declination: _declination,
                distKm: dist,
                accent: themeColor,
              ),
            ),
            const Gap.md(),
            Padding(
              padding: AppSpacing.screen,
              child: _SunCard(
                coords: city.coordinates,
                qiblaTrueBearing: bearing,
                dirLabel: _dirLabel,
                accent: themeColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Sağa/Sola N° çevir" / "Kıbleye dönüksün" yönlendirme rozeti.
class _TurnGuide extends StatelessWidget {
  final double? heading;
  final double? delta;
  final bool aligned;
  const _TurnGuide(
      {required this.heading, required this.delta, required this.aligned});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    IconData icon;
    String label;
    Color color;
    if (heading == null) {
      icon = Icons.screen_rotation_rounded;
      label = 'qibla.pointDevice'.tr();
      color = c.textSecondary;
    } else if (aligned) {
      icon = Icons.check_circle_rounded;
      label = 'qibla.facingQibla'.tr();
      color = c.success;
    } else {
      final right = (delta ?? 0) > 0;
      icon = right ? Icons.rotate_right_rounded : Icons.rotate_left_rounded;
      label =
          '${(right ? 'qibla.turnRight' : 'qibla.turnLeft').tr()} ${delta!.abs().round()}°';
      color = c.gold;
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const Gap.sm(),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pusula sensör hassasiyeti rozeti — kullanıcıya okumanın güvenilirliğini
/// anlık gösterir (önceden yalnızca düşükken uyarı vardı).
class _AccuracyChip extends StatelessWidget {
  final double? accuracy;
  const _AccuracyChip({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tr = context.langCode == 'tr';
    final acc = accuracy;
    final String label;
    final Color color;
    final IconData icon;
    if (acc == null) {
      label = tr ? 'Pusula hazır' : 'Compass ready';
      color = c.textTertiary;
      icon = Icons.explore_rounded;
    } else if (acc <= 12) {
      label = tr ? 'Hassas' : 'High accuracy';
      color = c.success;
      icon = Icons.gps_fixed_rounded;
    } else if (acc <= 25) {
      label = tr ? 'Orta hassasiyet' : 'Medium accuracy';
      color = const Color(0xFFD9A441);
      icon = Icons.gps_not_fixed_rounded;
    } else {
      label = tr ? 'Düşük — kalibre edin' : 'Low — calibrate';
      color = c.danger;
      icon = Icons.gps_off_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const Gap.xs(),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Pusula doğruluğu düşük / sensör yok uyarısı (8 çizerek kalibrasyon ipucu).
class _CalibrationBanner extends StatelessWidget {
  final bool supported;
  const _CalibrationBanner({required this.supported});

  static const _amber = Color(0xFFD9A441);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: 0.12),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: _amber.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.compass_calibration_rounded, color: _amber, size: 22),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((supported ? 'qibla.lowAccuracy' : 'qibla.noSensor').tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: _amber)),
                if (supported) ...[
                  const Gap.xs(),
                  Text('qibla.calibrateHint'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Koordinat · gerçek/manyetik yön · sapma · mesafe.
class _DetailsCard extends StatelessWidget {
  final String city;
  final LatLng coords;
  final double trueBearing;
  final double magneticBearing;
  final double declination;
  final double distKm;
  final Color accent;
  const _DetailsCard({
    required this.city,
    required this.coords,
    required this.trueBearing,
    required this.magneticBearing,
    required this.declination,
    required this.distKm,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final decl =
        '${declination >= 0 ? '+' : ''}${declination.toStringAsFixed(1)}°';
    final coordStr =
        '${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)}';
    return SelayaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: accent, size: 18),
              const Gap.sm(),
              Text('qibla.details'.tr(),
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Flexible(
                child: Text(city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: accent)),
              ),
            ],
          ),
          const Gap.sm(),
          _InfoRow('qibla.coordinates'.tr(), coordStr),
          _InfoRow('qibla.trueBearing'.tr(), '${trueBearing.round()}°'),
          _InfoRow('qibla.magneticBearing'.tr(), '${magneticBearing.round()}°'),
          _InfoRow('qibla.declination'.tr(), decl),
          _InfoRow('qibla.distance'.tr(), '${distKm.round()} km'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.textSecondary)),
          ),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Güneşle Kıble bulma — pusula yoksa/şüpheliyse gündüz çalışan yöntem.
class _SunCard extends StatelessWidget {
  final LatLng coords;
  final double qiblaTrueBearing;
  final String Function(double) dirLabel;
  final Color accent;
  const _SunCard({
    required this.coords,
    required this.qiblaTrueBearing,
    required this.dirLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sun = sunPosition(coords, DateTime.now().toUtc());
    final below = sun.altitude < 0;
    // Qibla relative to the sun (+ = qibla is to the right of the sun).
    final rel = ((qiblaTrueBearing - sun.azimuth + 540) % 360) - 180;
    final absRel = rel.abs().round();
    String relText = '';
    String helpText = '';
    if (!below) {
      if (absRel <= 3) {
        relText = 'qibla.sunAligned'.tr();
      } else if (rel > 0) {
        relText = 'qibla.sunRight'.tr(args: ['$absRel']);
        helpText = 'qibla.sunHelpRight'.tr(args: ['$absRel']);
      } else {
        relText = 'qibla.sunLeft'.tr(args: ['$absRel']);
        helpText = 'qibla.sunHelpLeft'.tr(args: ['$absRel']);
      }
    }
    return SelayaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_rounded, color: accent, size: 18),
              const Gap.sm(),
              Text('qibla.sunTitle'.tr(),
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const Gap.sm(),
          if (below)
            Text('qibla.sunBelow'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.textSecondary))
          else ...[
            Text(
                'qibla.sunNow'.tr(
                    args: [dirLabel(sun.azimuth), '${sun.azimuth.round()}']),
                style: Theme.of(context).textTheme.bodyMedium),
            const Gap.xs(),
            Text(relText,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: accent, fontWeight: FontWeight.w700)),
            if (helpText.isNotEmpty) ...[
              const Gap.xs(),
              Text(helpText,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textSecondary)),
            ],
          ],
        ],
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onPick;
  const _ThemePicker({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < _qiblaThemes.length; i++)
          GestureDetector(
            onTap: () => onPick(i),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Color.lerp(_qiblaThemes[i], Colors.white, 0.25)!,
                  _qiblaThemes[i],
                ]),
                border: Border.all(
                    color: i == selected ? c.textPrimary : c.border,
                    width: i == selected ? 2.5 : 1),
              ),
              child: i == selected
                  ? Icon(AppIcons.check, size: 16, color: c.onGold)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _Compass extends StatefulWidget {
  final double heading;
  final double bearing;
  final bool aligned;
  final Color themeColor;
  const _Compass({
    required this.heading,
    required this.bearing,
    required this.aligned,
    required this.themeColor,
  });

  @override
  State<_Compass> createState() => _CompassState();
}

class _CompassState extends State<_Compass> {
  // Sürekli (sarmalanmamış) tur değerleri: ibre/kadran 0°/360° sınırını
  // geçerken AnimatedRotation kısa yoldan dönsün diye biriktirilir. Aksi hâlde
  // (ham -heading/360 verilince) sınırda neredeyse tam tur ters yönden dönüyordu.
  double _dialTurns = 0;
  double _needleTurns = 0;

  @override
  void initState() {
    super.initState();
    _dialTurns = -widget.heading / 360;
    _needleTurns = (widget.bearing - widget.heading) / 360;
  }

  @override
  void didUpdateWidget(_Compass old) {
    super.didUpdateWidget(old);
    _dialTurns = shortestTurns(_dialTurns, -widget.heading / 360);
    _needleTurns =
        shortestTurns(_needleTurns, (widget.bearing - widget.heading) / 360);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final aligned = widget.aligned;
    final themeColor = widget.themeColor;
    final accent = aligned ? c.success : themeColor;
    final size = MediaQuery.sizeOf(context).width * 0.78;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // soft outer glow
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                accent.withValues(alpha: aligned ? 0.30 : 0.16),
                Colors.transparent,
              ], stops: const [0.55, 1]),
            ),
          ),
          // rotating dial (counter-rotates with the device)
          AnimatedRotation(
            turns: _dialTurns,
            duration: const Duration(milliseconds: 250),
            child: CustomPaint(
              size: Size(size, size),
              painter: _DialPainter(
                ring: c.border,
                tick: c.textTertiary,
                cardinal: c.textSecondary,
                gold: themeColor,
                north: c.danger,
              ),
            ),
          ),
          // inner disc
          Container(
            width: size * 0.60,
            height: size * 0.60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c.surfaceAlt, c.surface]),
              border: Border.all(color: c.border),
            ),
          ),
          // qibla needle (points toward the Kaaba relative to device)
          AnimatedRotation(
            turns: _needleTurns,
            duration: const Duration(milliseconds: 250),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(size, size),
                    painter: _NeedlePainter(accent: accent, tail: c.textTertiary),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: size * 0.085),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [accent, accent]),
                          boxShadow: [
                            BoxShadow(
                                color: accent.withValues(alpha: 0.6),
                                blurRadius: 18)
                          ],
                        ),
                        child: Icon(AppIcons.mosque,
                            color: c.onGold, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // center hub
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface,
              border: Border.all(color: accent, width: 2),
            ),
          ),
          // fixed top reference marker (device facing)
          Align(
            alignment: Alignment.topCenter,
            child: Icon(Icons.arrow_drop_down_rounded, color: accent, size: 34),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final Color ring;
  final Color tick;
  final Color cardinal;
  final Color gold;
  final Color north;
  _DialPainter(
      {required this.ring,
      required this.tick,
      required this.cardinal,
      required this.gold,
      required this.north});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    // gradient outer ring
    final ringRect = Rect.fromCircle(center: center, radius: r - 2);
    canvas.drawCircle(
      center,
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = SweepGradient(colors: [
          gold.withValues(alpha: 0.7),
          ring,
          gold.withValues(alpha: 0.7),
          ring,
          gold.withValues(alpha: 0.7),
        ]).createShader(ringRect),
    );

    for (int deg = 0; deg < 360; deg += 5) {
      final isMajor = deg % 45 == 0;
      final isMid = deg % 15 == 0;
      final a = (deg - 90) * math.pi / 180;
      final outer = r - 8;
      final inner = r - (isMajor ? 22 : (isMid ? 15 : 10));
      final p = Paint()
        ..strokeWidth = isMajor ? 2.5 : (isMid ? 1.5 : 1)
        ..color = isMajor
            ? gold
            : (isMid ? gold.withValues(alpha: 0.5) : tick.withValues(alpha: 0.6));
      canvas.drawLine(
        center + Offset(math.cos(a) * inner, math.sin(a) * inner),
        center + Offset(math.cos(a) * outer, math.sin(a) * outer),
        p,
      );
    }

    const labels = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};
    labels.forEach((deg, label) {
      final a = (deg - 90) * math.pi / 180;
      final pos = center + Offset(math.cos(a) * (r - 40), math.sin(a) * (r - 40));
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: TextStyle(
                color: deg == 0 ? north : cardinal,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.gold != gold || old.north != north;
}

class _NeedlePainter extends CustomPainter {
  final Color accent;
  final Color tail;
  _NeedlePainter({required this.accent, required this.tail});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final len = size.height * 0.30;

    // main needle (pointing up toward the Kaaba)
    final needle = Path()
      ..moveTo(cx, cy - len)
      ..lineTo(cx - 9, cy)
      ..lineTo(cx + 9, cy)
      ..close();
    canvas.drawPath(
      needle,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [accent, accent.withValues(alpha: 0.55)],
        ).createShader(Rect.fromLTWH(cx - 9, cy - len, 18, len)),
    );

    // muted tail (pointing down)
    final tailPath = Path()
      ..moveTo(cx, cy + len * 0.72)
      ..lineTo(cx - 6, cy)
      ..lineTo(cx + 6, cy)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = tail.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => old.accent != accent;
}
