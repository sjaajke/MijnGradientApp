import 'package:equatable/equatable.dart';
import '../../../domain/entities/analysis_result.dart';

abstract class AnalysisState extends Equatable {
  const AnalysisState();
}

class AnalysisInitial extends AnalysisState {
  const AnalysisInitial();
  @override
  List<Object?> get props => [];
}

class AnalysisLoading extends AnalysisState {
  const AnalysisLoading();
  @override
  List<Object?> get props => [];
}

class AnalysisLoaded extends AnalysisState {
  final AnalysisResult result;
  final bool showGradientOverlay;

  const AnalysisLoaded({
    required this.result,
    this.showGradientOverlay = false,
  });

  AnalysisLoaded copyWith({
    AnalysisResult? result,
    bool? showGradientOverlay,
  }) =>
      AnalysisLoaded(
        result: result ?? this.result,
        showGradientOverlay: showGradientOverlay ?? this.showGradientOverlay,
      );

  @override
  List<Object?> get props => [result, showGradientOverlay];
}

class AnalysisError extends AnalysisState {
  final String message;
  const AnalysisError(this.message);
  @override
  List<Object?> get props => [message];
}
