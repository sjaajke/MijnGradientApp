import '../../domain/entities/measurement_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../datasources/local_datasource.dart';
import '../models/session_model.dart';

class SessionRepositoryImpl implements SessionRepository {
  final LocalDataSource _local;
  SessionRepositoryImpl(this._local);

  @override
  Future<List<MeasurementSession>> getSessions() => _local.getSessions();

  @override
  Future<void> saveSession(MeasurementSession session) =>
      _local.saveSession(SessionModel.fromDomain(session));

  @override
  Future<void> deleteSession(String id) => _local.deleteSession(id);

  @override
  Future<MeasurementSession?> getSession(String id) => _local.getSession(id);
}
