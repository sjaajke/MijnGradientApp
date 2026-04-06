import 'dart:math' as math;
import '../../domain/entities/hotspot.dart';

/// Pure numerical / signal-processing utilities.
///
/// All functions are stateless and work on plain [List<double>].
class MathUtils {
  MathUtils._();

  // ─── Differentiation ────────────────────────────────────────────────────────

  /// Compute dT/dx at every sample using central differences for interior
  /// points and forward/backward differences at the endpoints.
  static List<double> computeGradient(
    List<double> temps,
    List<double> positions,
  ) {
    assert(temps.length == positions.length, 'arrays must be same length');
    final n = temps.length;
    if (n < 2) return List.filled(n, 0.0);

    final g = List<double>.filled(n, 0.0);

    // Interior — central differences
    for (int i = 1; i < n - 1; i++) {
      final dx = positions[i + 1] - positions[i - 1];
      if (dx.abs() > 1e-12) {
        g[i] = (temps[i + 1] - temps[i - 1]) / dx;
      }
    }

    // Endpoints — one-sided differences
    final dx0 = positions[1] - positions[0];
    if (dx0.abs() > 1e-12) g[0] = (temps[1] - temps[0]) / dx0;

    final dxN = positions[n - 1] - positions[n - 2];
    if (dxN.abs() > 1e-12) {
      g[n - 1] = (temps[n - 1] - temps[n - 2]) / dxN;
    }

    return g;
  }

  // ─── Smoothing filters ──────────────────────────────────────────────────────

  /// Symmetric moving-average with adaptive boundary handling.
  static List<double> movingAverage(List<double> data, int window) {
    if (window <= 1) return List<double>.from(data);
    final n = data.length;
    final result = List<double>.filled(n, 0.0);
    final half = window ~/ 2;

    for (int i = 0; i < n; i++) {
      final start = math.max(0, i - half);
      final end = math.min(n - 1, i + half);
      double sum = 0;
      for (int j = start; j <= end; j++) {
        sum += data[j];
      }
      result[i] = sum / (end - start + 1);
    }
    return result;
  }

  /// Savitzky-Golay 5-point quadratic smoothing.
  ///
  /// Coefficients: [−3, 12, 17, 12, −3] / 35.
  /// Boundary points (first/last 2) are left unchanged.
  static List<double> savitzkyGolay5(List<double> data) {
    const coeffs = [-3.0, 12.0, 17.0, 12.0, -3.0];
    const norm = 35.0;
    final n = data.length;
    final result = List<double>.from(data);

    for (int i = 2; i < n - 2; i++) {
      double sum = 0;
      for (int j = 0; j < 5; j++) {
        sum += coeffs[j] * data[i - 2 + j];
      }
      result[i] = sum / norm;
    }
    return result;
  }

  /// Convenience dispatcher — applies the requested smoothing filter.
  static List<double> smooth(
    List<double> data, {
    required SmootherType type,
    int window = 5,
  }) {
    switch (type) {
      case SmootherType.movingAverage:
        return movingAverage(data, window);
      case SmootherType.savitzkyGolay:
        return savitzkyGolay5(data);
      case SmootherType.none:
        return List<double>.from(data);
    }
  }

  // ─── Statistics ─────────────────────────────────────────────────────────────

  static double mean(List<double> data) {
    if (data.isEmpty) return 0;
    return data.reduce((a, b) => a + b) / data.length;
  }

  static double maxVal(List<double> data) {
    if (data.isEmpty) return 0;
    return data.reduce(math.max);
  }

  static double minVal(List<double> data) {
    if (data.isEmpty) return 0;
    return data.reduce(math.min);
  }

  static double absMax(List<double> data) {
    if (data.isEmpty) return 0;
    return data.map((v) => v.abs()).reduce(math.max);
  }

  static double absMean(List<double> data) {
    if (data.isEmpty) return 0;
    return mean(data.map((v) => v.abs()).toList());
  }

  // ─── Hotspot detection ──────────────────────────────────────────────────────

  /// Identify contiguous regions where |gradient| > mean(|gradient|) × [factor].
  static List<Hotspot> detectHotspots(
    List<double> gradients,
    List<double> positions,
    double factor,
  ) {
    final absG = gradients.map((g) => g.abs()).toList();
    if (absG.isEmpty) return [];

    final threshold = absMean(absG) * factor;
    final hotspots = <Hotspot>[];
    int? startIdx;

    for (int i = 0; i < absG.length; i++) {
      if (absG[i] > threshold) {
        startIdx ??= i;
      } else if (startIdx != null) {
        final peak = absG.sublist(startIdx, i).reduce(math.max);
        hotspots.add(Hotspot(
          startPosition: positions[startIdx],
          endPosition: positions[i - 1],
          startIndex: startIdx,
          endIndex: i - 1,
          peakGradient: peak,
          length: positions[i - 1] - positions[startIdx],
        ));
        startIdx = null;
      }
    }

    // Hotspot that reaches the last sample
    if (startIdx != null) {
      final peak = absG.sublist(startIdx).reduce(math.max);
      hotspots.add(Hotspot(
        startPosition: positions[startIdx],
        endPosition: positions.last,
        startIndex: startIdx,
        endIndex: absG.length - 1,
        peakGradient: peak,
        length: positions.last - positions[startIdx],
      ));
    }

    return hotspots;
  }

  // ─── Expected thermal model ─────────────────────────────────────────────────

  /// Simple steady-state 1-D model for a uniform conductor:
  ///   T(x) = T_ambient + (I² × resistivity × x × (L − x)) / (2 × λ × A²)
  ///
  /// Returns null if any parameter is zero or negative.
  static List<double>? expectedThermalProfile({
    required List<double> positions,
    required double current,
    required double resistancePerMeter, // Ω/m
    required double thermalConductivity, // W/(m·K)
    required double crossSectionArea, // m²
    required double ambientTemperature, // °C
  }) {
    if (current <= 0 ||
        resistancePerMeter <= 0 ||
        thermalConductivity <= 0 ||
        crossSectionArea <= 0) {
      return null;
    }

    final L = positions.last - positions.first;
    if (L <= 0) return null;

    final powerDensity = current * current * resistancePerMeter; // W/m

    return positions.map((x) {
      final xRel = x - positions.first;
      final t =
          ambientTemperature +
          (powerDensity * xRel * (L - xRel)) /
              (2.0 * thermalConductivity * crossSectionArea);
      return t;
    }).toList();
  }
}

/// Thin enum used inside [MathUtils] to avoid a dependency on app_constants.
enum SmootherType { none, movingAverage, savitzkyGolay }
