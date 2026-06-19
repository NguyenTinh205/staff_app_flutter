class PaymentMethodModel {
  final int id;
  final String name;
  final String code;
  final String description;
  final bool isActive;
  final String createdAt;

  PaymentMethodModel({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.isActive,
    required this.createdAt,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
}
