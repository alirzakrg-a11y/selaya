import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ISOLATION LAYER for the volatile `flutter_compass` package.
/// Nothing in `features/qibla` imports flutter_compass directly — they depend
/// on this service, so swapping the compass package is a one-file change.
/// Heading + sensor accuracy in a single reading. [accuracy] is the sensor's
/// reported uncertainty in degrees (lower = better; null = unknown).
class CompassReading {
  final double? heading;
  final double? accuracy;
  const CompassReading(this.heading, this.accuracy);
}

class QiblaSensorService {
  const QiblaSensorService();

  /// Whether the device exposes a magnetometer / compass.
  bool get isSupported => FlutterCompass.events != null;

  /// Device heading in degrees from magnetic north (0..360), or null if absent.
  Stream<double?> headingStream() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty();
    return events.map((e) => e.heading);
  }

  /// Heading + accuracy together (for the calibration/quality indicator).
  Stream<CompassReading> readingStream() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty();
    return events.map((e) => CompassReading(e.heading, e.accuracy));
  }
}

final qiblaSensorServiceProvider =
    Provider<QiblaSensorService>((ref) => const QiblaSensorService());

/// Live heading stream provider.
final headingProvider = StreamProvider.autoDispose<double?>(
  (ref) => ref.watch(qiblaSensorServiceProvider).headingStream(),
);

/// Live heading + accuracy reading provider.
final compassReadingProvider = StreamProvider.autoDispose<CompassReading>(
  (ref) => ref.watch(qiblaSensorServiceProvider).readingStream(),
);
