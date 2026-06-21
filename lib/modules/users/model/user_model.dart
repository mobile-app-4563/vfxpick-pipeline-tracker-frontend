class UserModel {
  final String userId;
  final String name;
  final String email;
  final String department;
  final String role; // Admin, Manager, Team Lead, Employee
  final String status; // Active, Disabled
  final String avatar; // Avatar initial or URL

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.department,
    required this.role,
    required this.status,
    required this.avatar,
  });

  UserModel copyWith({
    String? userId,
    String? name,
    String? email,
    String? department,
    String? role,
    String? status,
    String? avatar,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      department: department ?? this.department,
      role: role ?? this.role,
      status: status ?? this.status,
      avatar: avatar ?? this.avatar,
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
    };
  }
}
