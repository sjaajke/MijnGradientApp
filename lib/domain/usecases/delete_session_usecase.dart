import '../repositories/session_repository.dart';

class DeleteSessionUseCase {
  final SessionRepository _repository;
  DeleteSessionUseCase(this._repository);

  Future<void> call(String id) => _repository.deleteSession(id);
}
