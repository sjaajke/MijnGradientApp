import 'package:equatable/equatable.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/analysis_result.dart';
import '../../../domain/entities/conductor.dart';

abstract class AnalysisEvent extends Equatable {
  const AnalysisEvent();
}

class AnalyzeRequested extends AnalysisEvent {
  final Conductor conductor;
  final SmoothingMethod smoothingMethod;
  final int movingAverageWindow;
  final double hotspotFactor;

  const AnalyzeRequested({
    required this.conductor,
    this.smoothingMethod = SmoothingMethod.none,
    this.movingAverageWindow = 5,
    this.hotspotFactor = 2.0,
  });

  @override
  List<Object?> get props =>
      [conductor, smoothingMethod, movingAverageWindow, hotspotFactor];
}

class ToggleGradientOverlay extends AnalysisEvent {
  const ToggleGradientOverlay();
  @override
  List<Object?> get props => [];
}

class AnalysisReset extends AnalysisEvent {
  const AnalysisReset();
  @override
  List<Object?> get props => [];
}

class AnalysisResultRestored extends AnalysisEvent {
  final AnalysisResult result;
  const AnalysisResultRestored(this.result);
  @override
  List<Object?> get props => [result];
}
