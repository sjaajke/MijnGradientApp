import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/compare_conductors_usecase.dart';
import 'comparison_event.dart';
import 'comparison_state.dart';

class ComparisonBloc extends Bloc<ComparisonEvent, ComparisonState> {
  final CompareConductorsUseCase _compareUseCase;

  ComparisonBloc(this._compareUseCase) : super(const ComparisonInitial()) {
    on<CompareRequested>(_onCompareRequested);
    on<ComparisonReset>(_onReset);
    on<ComparisonSessionRestored>(_onSessionRestored);
  }

  void _onCompareRequested(
    CompareRequested event,
    Emitter<ComparisonState> emit,
  ) {
    try {
      final result = _compareUseCase(
        event.resultA,
        event.resultB,
        tolerance: event.tolerance,
      );
      emit(ComparisonLoaded(result));
    } catch (e) {
      emit(ComparisonError(e.toString()));
    }
  }

  void _onReset(ComparisonReset event, Emitter<ComparisonState> emit) {
    emit(const ComparisonInitial());
  }

  void _onSessionRestored(
    ComparisonSessionRestored event,
    Emitter<ComparisonState> emit,
  ) {
    emit(ComparisonPreloaded(resultA: event.resultA, resultB: event.resultB));
  }
}
