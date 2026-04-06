import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';
import 'analysis_result.dart';

/// Outcome of comparing two conductors.
class ComparisonResult extends Equatable {
  final AnalysisResult conductorA;
  final AnalysisResult conductorB;

  /// |normGradA − normGradB| / max(normGradA, normGradB)
  final double gradientDeviation;

  /// |hotspotLenA − hotspotLenB| / max(hotspotLenA, ε)
  final double hotspotDeviation;

  /// |ΔT_A − ΔT_B| / max(ΔT_A, ΔT_B)
  final double deltaTDeviation;

  final ConditionStatus status;

  /// Human-readable primary diagnosis.
  final String primaryDiagnosis;

  /// List of specific flags that contributed to the status.
  final List<String> flags;

  final double tolerance;

  const ComparisonResult({
    required this.conductorA,
    required this.conductorB,
    required this.gradientDeviation,
    required this.hotspotDeviation,
    required this.deltaTDeviation,
    required this.status,
    required this.primaryDiagnosis,
    required this.flags,
    required this.tolerance,
  });

  @override
  List<Object?> get props => [
        conductorA.conductor.id,
        conductorB.conductor.id,
        gradientDeviation,
        hotspotDeviation,
        deltaTDeviation,
        status,
      ];
}
