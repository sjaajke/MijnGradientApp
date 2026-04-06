import '../entities/measurement_session.dart';
import '../repositories/session_repository.dart';

class SaveSessionUseCase {
  final SessionRepository _repository;
  SaveSessionUseCase(this._repository);

  Future<void> call(MeasurementSession session) =>
      _repository.saveSession(session);
}
