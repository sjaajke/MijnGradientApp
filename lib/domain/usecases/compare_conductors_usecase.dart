import 'dart:math' as math;
import '../../core/constants/app_constants.dart';
import '../entities/analysis_result.dart';
import '../entities/comparison_result.dart';

class CompareConductorsUseCase {
  ComparisonResult call(
    AnalysisResult a,
    AnalysisResult b, {
    double tolerance = AppConstants.defaultTolerance,
  }) {
    // ── Compute deviations ──────────────────────────────────────────────────
    final maxNormGrad = math.max(a.normalizedGradient, b.normalizedGradient);
    final gradientDeviation = maxNormGrad > 0
        ? (a.normalizedGradient - b.normalizedGradient).abs() / maxNormGrad
        : 0.0;

    final maxHotspot = math.max(a.totalHotspotLength, b.totalHotspotLength);
    final hotspotDeviation =
        maxHotspot > 1e-6 // avoid division by zero
            ? (a.totalHotspotLength - b.totalHotspotLength).abs() / maxHotspot
            : 0.0;

    final maxDeltaT = math.max(a.deltaT, b.deltaT);
    final deltaTDeviation =
        maxDeltaT > 0 ? (a.deltaT - b.deltaT).abs() / maxDeltaT : 0.0;

    // ── Heuristic flags ─────────────────────────────────────────────────────
    final flags = <String>[];

    if (gradientDeviation > tolerance) {
      flags.add(
        'Normalised gradient differs by ${(gradientDeviation * 100).toStringAsFixed(1)} %',
      );
    }

    // Short + steep hotspot on one conductor but not the other
    final aHasShortSteep = a.hotspots.any((h) => h.isShort && h.peakGradient > 5 * a.meanAbsGradient);
    final bHasShortSteep = b.hotspots.any((h) => h.isShort && h.peakGradient > 5 * b.meanAbsGradient);

    if (aHasShortSteep && !bHasShortSteep) {
      flags.add(
        '${a.conductor.name}: short steep hotspot — possible contact resistance or localised defect.',
      );
    } else if (bHasShortSteep && !aHasShortSteep) {
      flags.add(
        '${b.conductor.name}: short steep hotspot — possible contact resistance or localised defect.',
      );
    }

    // ΔT disproportionate to current (expect ΔT ∝ I²)
    if (a.conductor.current > 0 && b.conductor.current > 0) {
      final expectedRatio =
          math.pow(a.conductor.current / b.conductor.current, 2).toDouble();
      final actualRatio = b.deltaT > 0 ? a.deltaT / b.deltaT : 0.0;
      final ratioDeviation =
          expectedRatio > 0 ? (actualRatio - expectedRatio).abs() / expectedRatio : 0.0;
      if (ratioDeviation > tolerance * 2) {
        flags.add(
          'ΔT deviation (${(ratioDeviation * 100).toStringAsFixed(1)} %) is disproportionate to I² ratio — unexpected heating source.',
        );
      }
    }

    if (hotspotDeviation > tolerance) {
      flags.add(
        'Hotspot length differs by ${(hotspotDeviation * 100).toStringAsFixed(1)} %.',
      );
    }

    // ── Determine overall status ─────────────────────────────────────────────
    final ConditionStatus status;
    final String primaryDiagnosis;

    final hasFaultFlag = aHasShortSteep ||
        bHasShortSteep ||
        gradientDeviation > AppConstants.faultThreshold ||
        deltaTDeviation > AppConstants.faultThreshold;

    if (hasFaultFlag) {
      status = ConditionStatus.fault;
      primaryDiagnosis =
          'Significant anomaly detected. Inspect for contact resistance, partial discharge, or insulation degradation.';
    } else if (gradientDeviation > AppConstants.warningThreshold ||
        hotspotDeviation > AppConstants.warningThreshold ||
        deltaTDeviation > AppConstants.warningThreshold) {
      status = ConditionStatus.warning;
      primaryDiagnosis =
          'Moderate deviation between conductors. Monitor closely and schedule inspection.';
    } else {
      status = ConditionStatus.ok;
      primaryDiagnosis =
          'Both conductors are within tolerance. Thermal profiles are consistent.';
    }

    return ComparisonResult(
      conductorA: a,
      conductorB: b,
      gradientDeviation: gradientDeviation,
      hotspotDeviation: hotspotDeviation,
      deltaTDeviation: deltaTDeviation,
      status: status,
      primaryDiagnosis: primaryDiagnosis,
      flags: flags,
      tolerance: tolerance,
    );
  }
}
