import '../entities/measurement_session.dart';
import '../repositories/session_repository.dart';

class GetSessionsUseCase {
  final SessionRepository _repository;
  GetSessionsUseCase(this._repository);

  Future<List<MeasurementSession>> call() => _repository.getSessions();
}
