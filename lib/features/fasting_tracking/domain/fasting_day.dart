/// A day's fasting state. [none] => not logged, [fasted] => oruç tutuldu,
/// [kaza] => kaçırıldı / kaza borcu.
enum FastStatus {
  none,
  fasted,
  kaza;

  /// Tap cycle: none → fasted → kaza → none.
  FastStatus get next => switch (this) {
        FastStatus.none => FastStatus.fasted,
        FastStatus.fasted => FastStatus.kaza,
        FastStatus.kaza => FastStatus.none,
      };

  /// Persisted id (null when not logged).
  String? get id => this == FastStatus.none ? null : name;

  static FastStatus fromId(String? s) => switch (s) {
        'fasted' => FastStatus.fasted,
        'kaza' => FastStatus.kaza,
        _ => FastStatus.none,
      };
}
