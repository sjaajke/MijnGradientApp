import '../entities/measurement_session.dart';

/// Abstract repository — implemented in the data layer.
abstract class SessionRepository {
  Future<List<MeasurementSession>> getSessions();
  Future<void> saveSession(MeasurementSession session);
  Future<void> deleteSession(String id);
  Future<MeasurementSession?> getSession(String id);
}
