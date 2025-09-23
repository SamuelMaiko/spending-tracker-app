import 'package:get_it/get_it.dart';

import 'features/sms/data/datasources/sms_datasource.dart';
import 'features/sms/data/repositories/sms_repository_impl.dart';
import 'features/sms/domain/repositories/sms_repository.dart';
import 'features/sms/domain/usecases/get_sms_messages.dart';
import 'features/sms/domain/usecases/listen_for_sms.dart';
import 'features/sms/domain/usecases/request_sms_permissions.dart';
import 'features/sms/presentation/bloc/sms_bloc.dart';

/// Service locator instance for dependency injection
///
/// This follows the Clean Architecture pattern by providing a centralized
/// way to manage dependencies across the application
final GetIt sl = GetIt.instance;

/// Initialize all dependencies for the application
///
/// This function sets up the dependency injection container with all
/// the required services, repositories, use cases, and BLoCs
Future<void> initializeDependencies() async {
  // Data sources
  sl.registerLazySingleton<SmsDataSource>(() => SmsDataSourceImpl());

  // Repositories
  sl.registerLazySingleton<SmsRepository>(
    () => SmsRepositoryImpl(sl<SmsDataSource>()),
  );

  // Use cases
  sl.registerLazySingleton<RequestSmsPermissions>(
    () => RequestSmsPermissions(sl<SmsRepository>()),
  );

  sl.registerLazySingleton<GetSmsMessages>(
    () => GetSmsMessages(sl<SmsRepository>()),
  );

  sl.registerLazySingleton<ListenForSms>(
    () => ListenForSms(sl<SmsRepository>()),
  );

  // BLoCs
  sl.registerFactory<SmsBloc>(
    () => SmsBloc(
      requestPermissions: sl<RequestSmsPermissions>(),
      getSmsMessages: sl<GetSmsMessages>(),
      listenForSms: sl<ListenForSms>(),
    ),
  );
}

/// Clean up all dependencies
///
/// This should be called when the app is being disposed
Future<void> disposeDependencies() async {
  await sl.reset();
}
