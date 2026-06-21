import 'package:flutter_test/flutter_test.dart';
import 'package:selaya/core/utils/geo.dart';

/// Kıble pusulası ibre dönüşü hatasının kök fonksiyonu: ibre 0°/360° sınırını
/// geçerken AnimatedRotation'ın UZUN yoldan (ters) dönmesini engelleyen
/// "en kısa tur" sarması. Emülatörde manyetometre olmadığı için bu mantık
/// yalnızca birim testle güvence altına alınabilir.
void main() {
  group('shortestTurns', () {
    test('hedef = mevcut iken hareket yok', () {
      expect(shortestTurns(0, 0), 0);
    });

    test('küçük ileri adım aynen korunur', () {
      expect(shortestTurns(0.0, 0.1), closeTo(0.1, 1e-9));
    });

    test('0/1 sınırını UZUN yoldan geçmez (asıl hata)', () {
      // Pusula 359° → kadran turu ≈ -0.99722; 1° → ham hedef ≈ -0.00278.
      const current = -0.99722;
      const target = -0.00278;
      final r = shortestTurns(current, target);
      // Delta KISA yol olmalı (~ -0.0056), hatalı +0.9944 değil.
      expect((r - current).abs(), lessThan(0.5));
      expect(r - current, closeTo(-0.00556, 1e-3));
    });

    test('pozitif sarma geri-kısa yolu seçer (0.95 → 0.05 = +0.1)', () {
      expect(shortestTurns(0.95, 0.05), closeTo(1.05, 1e-9));
    });

    test('negatif sarma ileri-kısa yolu seçer (0.05 → 0.95 = -0.1)', () {
      expect(shortestTurns(0.05, 0.95), closeTo(-0.05, 1e-9));
    });

    test('art arda hedeflerde delta hep ≤ yarım tur + yön korunur', () {
      var current = 0.0;
      for (final t in [0.4, 0.9, 0.1, 0.6, 0.95, 0.05, 0.5, 0.0]) {
        final next = shortestTurns(current, t);
        // her adım en fazla yarım tur oynar
        expect((next - current).abs(), lessThanOrEqualTo(0.5 + 1e-9),
            reason: 'current=$current target=$t next=$next');
        // sonuç hedefe tur (mod 1) olarak denk olmalı
        final frac = (next - t) % 1.0;
        expect(frac < 1e-9 || (1 - frac) < 1e-9, isTrue,
            reason: 'next=$next hedefe (mod 1) denk değil: $t');
        current = next;
      }
    });
  });
}
