class MemberModel {
  final int id;
  final String phoneNumber;
  final String fullName;
  final int currentPoints;
  final String tierName;
  final num pointMultiplier;

  MemberModel({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.currentPoints,
    required this.tierName,
    required this.pointMultiplier,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    int parseToInt(dynamic val, int defaultVal) {
      if (val == null) return defaultVal;
      if (val is num) return val.toInt();
      if (val is String) {
        return int.tryParse(val) ?? defaultVal;
      }
      return defaultVal;
    }

    // Xử lý đọc tier name và point multiplier từ object tier lồng nhau (theo API thực tế)
    String nameOfTier = 'MEMBER';
    num multiplier = 1.0;
    if (json['tier'] != null && json['tier'] is Map) {
      nameOfTier =
          json['tier']['name']?.toString() ??
          json['tier']['tier_name']?.toString() ??
          'MEMBER';
      multiplier = json['tier']['point_multiplier'] is num
          ? (json['tier']['point_multiplier'] as num)
          : (double.tryParse(
                  json['tier']['point_multiplier']?.toString() ?? '1.0',
                ) ??
                1.0);
    } else {
      nameOfTier = json['tier_name']?.toString() ?? 'MEMBER';
      multiplier = json['point_multiplier'] is num
          ? (json['point_multiplier'] as num)
          : (double.tryParse(json['point_multiplier']?.toString() ?? '1.0') ??
                1.0);
    }

    return MemberModel(
      id: parseToInt(json['id'], 0),
      phoneNumber: json['phone_number']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      currentPoints: parseToInt(json['current_points'], 0),
      tierName: nameOfTier,
      pointMultiplier: multiplier,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'current_points': currentPoints,
      'tier_name': tierName,
      'point_multiplier': pointMultiplier,
    };
  }
}
