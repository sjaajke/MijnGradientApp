import 'package:equatable/equatable.dart';
import '../../../domain/entities/analysis_result.dart';

abstract class ComparisonEvent extends Equatable {
  const ComparisonEvent();
}

class CompareRequested extends ComparisonEvent {
  final AnalysisResult resultA;
  final AnalysisResult resultB;
  final double tolerance;

  const CompareRequested({
    required this.resultA,
    required this.resultB,
    this.tolerance = 0.15,
  });

  @override
  List<Object?> get props => [resultA, resultB, tolerance];
}

class ComparisonReset extends ComparisonEvent {
  const ComparisonReset();
  @override
  List<Object?> get props => [];
}

class ComparisonSessionRestored extends ComparisonEvent {
  final AnalysisResult resultA;
  final AnalysisResult? resultB;

  const ComparisonSessionRestored({required this.resultA, this.resultB});

  @override
  List<Object?> get props => [resultA, resultB];
}
