import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../domain/repositories/auth_repository.dart';

class LoginController extends ChangeNotifier {
  final AuthRepository authRepository;

  LoginController({required this.authRepository});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await authRepository.login(identifier, password);
      
      if (result.success) {
        // Lưu thông tin đăng nhập vào FlutterSecureStorage
        const storage = FlutterSecureStorage();
        await storage.write(key: 'access_token', value: result.accessToken);
        await storage.write(
          key: 'employee_info',
          value: jsonEncode({
            'id': result.employee.id,
            'employee_code': result.employee.employeeCode,
            'email': result.employee.email,
            'role': result.employee.role,
          }),
        );
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token != null) {
        await authRepository.logout(token);
      }
    } catch (e) {
      debugPrint("DEBUG LOGOUT ERROR: $e");
    } finally {
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'employee_info');
      _isLoading = false;
      notifyListeners();
    }
  }
}
