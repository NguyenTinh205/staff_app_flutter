import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:staffapp/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:staffapp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:staffapp/features/auth/domain/repositories/auth_repository.dart';
import 'package:staffapp/features/auth/presentation/controllers/login_controller.dart';
import 'package:staffapp/features/home/data/datasources/product_remote_data_source.dart';
import 'package:staffapp/features/home/data/repositories/product_repository_impl.dart';
import 'package:staffapp/features/home/domain/repositories/product_repository.dart';
import 'package:staffapp/features/home/presentation/controllers/product_controller.dart';

final sl = GetIt.instance; // sl: Service Locator

Future<void> init() async {
  // External
  sl.registerLazySingleton(() => http.Client());

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSourceImpl(client: sl(), storage: const FlutterSecureStorage()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(remoteDataSource: sl()),
  );

  // Controllers / Presenters
  sl.registerFactory(
    () => LoginController(authRepository: sl()),
  );
  sl.registerFactory(
    () => ProductController(productRepository: sl()),
  );
}
