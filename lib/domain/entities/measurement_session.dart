import 'package:equatable/equatable.dart';
import 'analysis_result.dart';
import 'comparison_result.dart';
import 'conductor.dart';

/// A persisted measurement session containing one or two conductors.
class MeasurementSession extends Equatable {
  final String id;
  final String name;
  final DateTime createdAt;
  final Conductor conductorA;
  final Conductor? conductorB;
  final AnalysisResult analysisA;
  final AnalysisResult? analysisB;
  final ComparisonResult? comparison;

  const MeasurementSession({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.conductorA,
    this.conductorB,
    required this.analysisA,
    this.analysisB,
    this.comparison,
  });

  bool get hasComparison => comparison != null;

  @override
  List<Object?> get props => [id, name, createdAt];
}
