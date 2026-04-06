import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/delete_session_usecase.dart';
import '../../../domain/usecases/get_sessions_usecase.dart';
import '../../../domain/usecases/save_session_usecase.dart';
import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final GetSessionsUseCase _getSessions;
  final SaveSessionUseCase _saveSession;
  final DeleteSessionUseCase _deleteSession;

  SessionBloc(this._getSessions, this._saveSession, this._deleteSession)
      : super(const SessionInitial()) {
    on<SessionsLoadRequested>(_onLoad);
    on<SessionSaveRequested>(_onSave);
    on<SessionDeleteRequested>(_onDelete);
  }

  Future<void> _onLoad(
    SessionsLoadRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(const SessionLoading());
    try {
      final sessions = await _getSessions();
      emit(SessionLoaded(sessions));
    } catch (e) {
      emit(SessionError(e.toString()));
    }
  }

  Future<void> _onSave(
    SessionSaveRequested event,
    Emitter<SessionState> emit,
  ) async {
    try {
      await _saveSession(event.session);
      emit(const SessionSaved());
      add(const SessionsLoadRequested());
    } catch (e) {
      emit(SessionError(e.toString()));
    }
  }

  Future<void> _onDelete(
    SessionDeleteRequested event,
    Emitter<SessionState> emit,
  ) async {
    try {
      await _deleteSession(event.id);
      add(const SessionsLoadRequested());
    } catch (e) {
      emit(SessionError(e.toString()));
    }
  }
}
