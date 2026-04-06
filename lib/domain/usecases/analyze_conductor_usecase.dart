import '../../core/constants/app_constants.dart';
import '../../core/utils/math_utils.dart';
import '../entities/analysis_result.dart';
import '../entities/conductor.dart';

class AnalyzeConductorParams {
  final Conductor conductor;
  final SmoothingMethod smoothingMethod;
  final int movingAverageWindow;
  final double hotspotFactor;

  const AnalyzeConductorParams({
    required this.conductor,
    this.smoothingMethod = SmoothingMethod.none,
    this.movingAverageWindow = AppConstants.defaultMovingAverageWindow,
    this.hotspotFactor = AppConstants.defaultHotspotFactor,
  });
}

class AnalyzeConductorUseCase {
  AnalysisResult call(AnalyzeConductorParams params) {
    final c = params.conductor;

    if (!c.isValid) {
      throw ArgumentError(
        'Conductor "${c.name}" is invalid: positions and temperatures must '
        'have at least 3 matching values.',
      );
    }

    // 1. Smooth temperatures if requested
    final SmootherType smootherType;
    switch (params.smoothingMethod) {
      case SmoothingMethod.movingAverage:
        smootherType = SmootherType.movingAverage;
      case SmoothingMethod.savitzkyGolay:
        smootherType = SmootherType.savitzkyGolay;
      case SmoothingMethod.none:
        smootherType = SmootherType.none;
    }

    final effectiveTemps = MathUtils.smooth(
      c.temperatures,
      type: smootherType,
      window: params.movingAverageWindow,
    );

    // 2. Compute gradient on smoothed temperatures
    final gradients = MathUtils.computeGradient(effectiveTemps, c.positions);

    // 3. Statistics
    final maxTemp = MathUtils.maxVal(effectiveTemps);
    final minTemp = MathUtils.minVal(effectiveTemps);
    final deltaT = maxTemp - minTemp;
    final maxAbsGrad = MathUtils.absMax(gradients);
    final meanAbsGrad = MathUtils.absMean(gradients);
    final normalizedGradient =
        c.current > 0 ? maxAbsGrad / c.current : maxAbsGrad;

    // 4. Hotspot detection
    final hotspots = MathUtils.detectHotspots(
      gradients,
      c.positions,
      params.hotspotFactor,
    );
    final totalHotspotLength =
        hotspots.fold(0.0, (sum, h) => sum + h.length);

    return AnalysisResult(
      conductor: c,
      effectiveTemps: effectiveTemps,
      gradients: gradients,
      deltaT: deltaT,
      maxTemperature: maxTemp,
      minTemperature: minTemp,
      maxAbsGradient: maxAbsGrad,
      meanAbsGradient: meanAbsGrad,
      normalizedGradient: normalizedGradient,
      hotspots: hotspots,
      totalHotspotLength: totalHotspotLength,
      hotspotFactor: params.hotspotFactor,
      smoothingMethod: params.smoothingMethod,
    );
  }
}
