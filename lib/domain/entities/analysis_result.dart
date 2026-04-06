import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';
import 'conductor.dart';
import 'hotspot.dart';

/// Complete analysis output for a single conductor.
class AnalysisResult extends Equatable {
  final Conductor conductor;

  /// Temperatures after smoothing (or raw when smoothing = none).
  final List<double> effectiveTemps;

  /// Gradient dT/dx computed from [effectiveTemps] (°C/m).
  final List<double> gradients;

  final double deltaT; // max − min (°C)
  final double maxTemperature; // °C
  final double minTemperature; // °C

  /// Absolute maximum gradient along the conductor (°C/m).
  final double maxAbsGradient;

  /// Mean of absolute gradient values (°C/m).
  final double meanAbsGradient;

  /// maxAbsGradient / current  (°C/m/A) — current-normalised gradient.
  final double normalizedGradient;

  final List<Hotspot> hotspots;
  final double totalHotspotLength; // metres

  /// Multiplier used for hotspot detection (threshold = mean * factor).
  final double hotspotFactor;
  final SmoothingMethod smoothingMethod;

  const AnalysisResult({
    required this.conductor,
    required this.effectiveTemps,
    required this.gradients,
    required this.deltaT,
    required this.maxTemperature,
    required this.minTemperature,
    required this.maxAbsGradient,
    required this.meanAbsGradient,
    required this.normalizedGradient,
    required this.hotspots,
    required this.totalHotspotLength,
    required this.hotspotFactor,
    required this.smoothingMethod,
  });

  /// Engineering heuristic interpretation of hotspot pattern.
  String get hotspotDiagnosis {
    if (hotspots.isEmpty) return 'No hotspots detected — thermal profile is uniform.';

    final avgLen = totalHotspotLength / hotspots.length;
    final hasShortSteep = hotspots.any(
      (h) =>
          h.isShort &&
          normalizedGradient >
              AppConstants.steepNormGradientThreshold,
    );

    if (hasShortSteep) {
      return 'Short, steep hotspot detected — likely contact resistance or localised defect.';
    } else if (avgLen > 0.20) {
      return 'Long, smooth gradient — consistent with normal resistive heating distribution.';
    } else {
      return 'Moderate hotspot detected — further investigation recommended.';
    }
  }

  @override
  List<Object?> get props => [
        conductor.id,
        deltaT,
        maxAbsGradient,
        normalizedGradient,
        hotspots.length,
        totalHotspotLength,
      ];
}
