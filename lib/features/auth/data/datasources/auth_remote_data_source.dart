import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/login_response_model.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponseModel> login(String identifier, String password);
  Future<void> logout(String token);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client client;
  final String baseUrl = 'https://nonoily-overinfluential-deegan.ngrok-free.dev/api';

  AuthRemoteDataSourceImpl({required this.client});

   @override
  Future<LoginResponseModel> login(String identifier, String password) async {
    final response = await client.post(
      Uri.parse('$baseUrl/employee/login'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      return LoginResponseModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Đăng nhập không thành công');
    }
  }

  @override
  Future<void> logout(String token) async {
    final response = await client.post(
      Uri.parse('$baseUrl/employee/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Đăng xuất không thành công');
    }
  }
}