import '../../data/models/login_response_model.dart';

abstract class AuthRepository {
  Future<LoginResponseModel> login(String identifier, String password);
  Future<void> logout(String token);
}
