import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/login_response_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<LoginResponseModel> login(String identifier, String password) {
    return remoteDataSource.login(identifier, password);
  }

  @override
  Future<void> logout(String token) {
    return remoteDataSource.logout(token);
  }
}
