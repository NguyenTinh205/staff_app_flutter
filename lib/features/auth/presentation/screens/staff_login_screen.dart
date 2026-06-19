import 'package:flutter/material.dart';
import 'package:staffapp/core/di/injection.dart';
import 'package:staffapp/features/auth/presentation/controllers/login_controller.dart';
import 'package:staffapp/features/home/presentation/screens/home_shell_screen.dart';
import 'package:staffapp/core/widgets/custom_notification.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _employeeCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late final LoginController _loginController;

  @override
  void initState() {
    super.initState();
    _loginController = sl<LoginController>();
    _loginController.addListener(_onLoginStateChanged);
  }

  @override
  void dispose() {
    _loginController.removeListener(_onLoginStateChanged);
    _employeeCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginStateChanged() {
    // Kích hoạt build lại để cập nhật giao diện (loading state)
    setState(() {});
    
    if (_loginController.errorMessage != null) {
      CustomNotification.show(
        context,
        message: _loginController.errorMessage!,
        backgroundColor: Colors.redAccent,
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _handleLogin() async {
    final identifier = _employeeCodeController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      CustomNotification.show(
        context,
        message: 'Vui lòng nhập đầy đủ thông tin!',
        backgroundColor: Colors.orangeAccent,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    final success = await _loginController.login(identifier, password);
    if (success && mounted) {
      CustomNotification.show(
        context,
        message: 'Đăng nhập thành công! Chào mừng trở lại.',
        backgroundColor: Colors.green,
        icon: Icons.check_circle_outline,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeShellScreen(),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111110),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B5805),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.tv,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  const Text(
                    'Loyalty Buffet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFED876),
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Subtitle
                  const SizedBox(height: 36),
                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222221),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF333332),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mã nhân viên Label
                        const Row(
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              color: Color(0xFF7A704A),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'MÃ NHÂN VIÊN',
                              style: TextStyle(
                                color: Color(0xFF7A704A),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Mã nhân viên Input
                        TextField(
                          controller: _employeeCodeController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Nhập mã NV',
                            hintStyle: const TextStyle(
                              color: Color(0xFF555555),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1A1A19),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E2E2D),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E2E2D),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFFED876),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Mật khẩu / PIN Label
                        const Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: Color(0xFF7A704A),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'MẬT KHẨU / PIN',
                              style: TextStyle(
                                color: Color(0xFF7A704A),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Mật khẩu / PIN Input
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: const TextStyle(
                              color: Color(0xFF555555),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1A1A19),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF555555),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E2E2D),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E2E2D),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFFED876),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Button Đăng nhập
                        SizedBox(
                          height: 58,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFED876),
                              foregroundColor: const Color(0xFF1E1E1E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _loginController.isLoading ? null : _handleLogin,
                            child: _loginController.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF1E1E1E),
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text('Đăng nhập'),
                          ),
                        ),

                        const SizedBox(height: 24),
                        // Divider Line
                        const Divider(
                          color: Color(0xFF2E2E2D),
                          height: 1,
                        ),
                        const SizedBox(height: 20),
                        // Quên mã PIN?
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            'Quên mã PIN?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Footer
                  const Text(
                    'Hệ thống quản lý nội bộ dành riêng cho nhân viên Loyalty Buffet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF3E3E3D),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '© 2024 Buffet POS Solutions. All rights reserved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF3E3E3D),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

