class UserModel {
  final String userId;
  final String name;
  final String email;
  final String department;
  final String role; // Admin, Manager, Team Lead, Employee
  final String status; // Active, Disabled
  final String avatar; // Avatar initial or URL
  final String level; // Senior | Mid | Junior (artists only)
  final String phone;
  final String employeeId;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.department,
    required this.role,
    required this.status,
    required this.avatar,
    this.level = '',
    this.phone = '',
    this.employeeId = '',
  });

  UserModel copyWith({
    String? userId,
    String? name,
    String? email,
    String? department,
    String? role,
    String? status,
    String? avatar,
    String? level,
    String? phone,
    String? employeeId,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      department: department ?? this.department,
      role: role ?? this.role,
      status: status ?? this.status,
      avatar: avatar ?? this.avatar,
      level: level ?? this.level,
      phone: phone ?? this.phone,
      employeeId: employeeId ?? this.employeeId,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      department: json['department'] ?? '',
      role: json['role'] ?? '',
      status: json['status'] ?? 'Active',
      avatar: json['avatar'] ?? '',
      level: json['level'] ?? '',
      phone: json['phone'] ?? '',
      employeeId: json['employeeId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'department': department,
      'role': role,
      'status': status,
      'avatar': avatar,
      'level': level,
      'phone': phone,
      'employeeId': employeeId,
    };
  }
}
