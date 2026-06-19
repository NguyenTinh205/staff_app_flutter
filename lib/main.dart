import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:staffapp/core/di/injection.dart' as di;
import 'package:staffapp/features/auth/presentation/screens/staff_login_screen.dart';
import 'package:staffapp/features/home/presentation/screens/home_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khóa xoay màn hình nằm ngang giống giao diện Tablet
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await di.init();
  
  bool isLoggedIn = false;
  try {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    isLoggedIn = token != null;
  } catch (e) {
    debugPrint("Lỗi đọc Secure Storage: $e");
  }
  
  runApp(MainApp(isLoggedIn: isLoggedIn));
}

class MainApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const MainApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TiVi buffet Staff',
      home: isLoggedIn ? const HomeShellScreen() : const StaffLoginScreen(),
    );
  }
}
