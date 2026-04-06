import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/usecases/analyze_conductor_usecase.dart';
import '../../domain/usecases/compare_conductors_usecase.dart';
import '../../domain/usecases/delete_session_usecase.dart';
import '../../domain/usecases/export_report_usecase.dart';
import '../../domain/usecases/get_sessions_usecase.dart';
import '../../domain/usecases/import_csv_usecase.dart';
import '../../domain/usecases/save_session_usecase.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // External
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // Data sources
  sl.registerLazySingleton(() => LocalDataSource(sl<SharedPreferences>()));

  // Repositories
  sl.registerLazySingleton<SessionRepository>(
    () => SessionRepositoryImpl(sl<LocalDataSource>()),
  );

  // Use cases
  sl.registerLazySingleton(() => AnalyzeConductorUseCase());
  sl.registerLazySingleton(() => CompareConductorsUseCase());
  sl.registerLazySingleton(() => ImportCsvUseCase());
  sl.registerLazySingleton(() => ExportReportUseCase());
  sl.registerLazySingleton(() => SaveSessionUseCase(sl<SessionRepository>()));
  sl.registerLazySingleton(() => GetSessionsUseCase(sl<SessionRepository>()));
  sl.registerLazySingleton(() => DeleteSessionUseCase(sl<SessionRepository>()));
}
