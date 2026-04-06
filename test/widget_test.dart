import 'package:flutter_test/flutter_test.dart';
import 'package:mijn_gradient_app/core/utils/math_utils.dart';

void main() {
  group('MathUtils', () {
    test('computeGradient — central differences', () {
      final positions = [0.0, 0.1, 0.2, 0.3, 0.4];
      final temps = [20.0, 22.0, 26.0, 30.0, 32.0];
      final g = MathUtils.computeGradient(temps, positions);
      expect(g.length, equals(5));
      expect(g[2].abs(), greaterThan(g[0].abs()));
    });

    test('movingAverage — smooths spike', () {
      final data = [10.0, 10.0, 100.0, 10.0, 10.0];
      final smooth = MathUtils.movingAverage(data, 3);
      expect(smooth[2], lessThan(100.0));
    });

    test('detectHotspots — single hotspot', () {
      final positions = List.generate(10, (i) => i * 0.1);
      final gradients = [0.0, 0.0, 0.0, 0.0, 0.0, 10.0, 10.0, 0.0, 0.0, 0.0];
      final hotspots = MathUtils.detectHotspots(gradients, positions, 2.0);
      expect(hotspots, isNotEmpty);
    });
  });
}
