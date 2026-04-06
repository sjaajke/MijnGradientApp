import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/analyze_conductor_usecase.dart';
import 'analysis_event.dart';
import 'analysis_state.dart';

class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {
  final AnalyzeConductorUseCase _analyzeUseCase;

  AnalysisBloc(this._analyzeUseCase) : super(const AnalysisInitial()) {
    on<AnalyzeRequested>(_onAnalyzeRequested);
    on<ToggleGradientOverlay>(_onToggleGradientOverlay);
    on<AnalysisReset>(_onReset);
    on<AnalysisResultRestored>(_onResultRestored);
  }

  void _onAnalyzeRequested(
    AnalyzeRequested event,
    Emitter<AnalysisState> emit,
  ) {
    emit(const AnalysisLoading());
    try {
      final result = _analyzeUseCase(
        AnalyzeConductorParams(
          conductor: event.conductor,
          smoothingMethod: event.smoothingMethod,
          movingAverageWindow: event.movingAverageWindow,
          hotspotFactor: event.hotspotFactor,
        ),
      );
      emit(AnalysisLoaded(result: result));
    } catch (e) {
      emit(AnalysisError(e.toString()));
    }
  }

  void _onToggleGradientOverlay(
    ToggleGradientOverlay event,
    Emitter<AnalysisState> emit,
  ) {
    if (state is AnalysisLoaded) {
      final current = state as AnalysisLoaded;
      emit(current.copyWith(
        showGradientOverlay: !current.showGradientOverlay,
      ));
    }
  }

  void _onReset(AnalysisReset event, Emitter<AnalysisState> emit) {
    emit(const AnalysisInitial());
  }

  void _onResultRestored(
    AnalysisResultRestored event,
    Emitter<AnalysisState> emit,
  ) {
    emit(AnalysisLoaded(result: event.result));
  }
}
