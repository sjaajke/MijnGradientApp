import 'package:equatable/equatable.dart';
import '../../../domain/entities/analysis_result.dart';
import '../../../domain/entities/comparison_result.dart';

abstract class ComparisonState extends Equatable {
  const ComparisonState();
}

class ComparisonInitial extends ComparisonState {
  const ComparisonInitial();
  @override
  List<Object?> get props => [];
}

class ComparisonLoaded extends ComparisonState {
  final ComparisonResult result;
  const ComparisonLoaded(this.result);
  @override
  List<Object?> get props => [result];
}

class ComparisonError extends ComparisonState {
  final String message;
  const ComparisonError(this.message);
  @override
  List<Object?> get props => [message];
}

class ComparisonPreloaded extends ComparisonState {
  final AnalysisResult resultA;
  final AnalysisResult? resultB;

  const ComparisonPreloaded({required this.resultA, this.resultB});

  @override
  List<Object?> get props => [resultA, resultB];
}
