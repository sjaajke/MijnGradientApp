import 'package:equatable/equatable.dart';
import '../../../domain/entities/measurement_session.dart';

abstract class SessionEvent extends Equatable {
  const SessionEvent();
}

class SessionsLoadRequested extends SessionEvent {
  const SessionsLoadRequested();
  @override
  List<Object?> get props => [];
}

class SessionSaveRequested extends SessionEvent {
  final MeasurementSession session;
  const SessionSaveRequested(this.session);
  @override
  List<Object?> get props => [session.id];
}

class SessionDeleteRequested extends SessionEvent {
  final String id;
  const SessionDeleteRequested(this.id);
  @override
  List<Object?> get props => [id];
}
