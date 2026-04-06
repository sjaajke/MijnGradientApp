import 'package:equatable/equatable.dart';
import '../../../domain/entities/measurement_session.dart';

abstract class SessionState extends Equatable {
  const SessionState();
}

class SessionInitial extends SessionState {
  const SessionInitial();
  @override
  List<Object?> get props => [];
}

class SessionLoading extends SessionState {
  const SessionLoading();
  @override
  List<Object?> get props => [];
}

class SessionLoaded extends SessionState {
  final List<MeasurementSession> sessions;
  const SessionLoaded(this.sessions);
  @override
  List<Object?> get props => [sessions];
}

class SessionError extends SessionState {
  final String message;
  const SessionError(this.message);
  @override
  List<Object?> get props => [message];
}

class SessionSaved extends SessionState {
  const SessionSaved();
  @override
  List<Object?> get props => [];
}
