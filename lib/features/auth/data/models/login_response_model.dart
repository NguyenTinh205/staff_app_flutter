class LoginResponseModel {
  final bool success;
  final String message;
  final String accessToken;
  final EmployeeModel employee;

  LoginResponseModel({
    required this.success,
    required this.message,
    required this.accessToken,
    required this.employee,
  });
  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      accessToken: json['data']['access_token'] ?? '',
      employee: EmployeeModel.fromJson(json['data']['employee']),
    );
  }

}
class EmployeeModel {
  final String id;
  final String employeeCode;
  final String email;
  final String role;
  EmployeeModel({
    required this.id,
    required this.employeeCode,
    required this.email,
    required this.role,
  });
  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'].toString(),
      employeeCode: json['employee_code'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
    );
  }
}