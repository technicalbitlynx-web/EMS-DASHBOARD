/// An EMS user account. Roles: admin | operator | viewer.
class User {
  const User({
    required this.email,
    required this.username,
    required this.role,
    this.fullName,
    this.department,
    this.phone,
    this.lastLogin,
    this.createdAt,
  });

  final String email;
  final String username;
  final String role;
  final String? fullName;
  final String? department;
  final String? phone;
  final String? lastLogin;
  final String? createdAt;

  bool get isAdmin => role == 'admin';
  bool get isOperator => role == 'operator';
  bool get canWrite => role == 'admin' || role == 'operator';

  String get displayName =>
      (fullName != null && fullName!.isNotEmpty) ? fullName! : username;

  factory User.fromJson(Map<String, dynamic> j) => User(
        email: (j['email'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        role: (j['role'] ?? 'viewer').toString(),
        fullName: j['full_name']?.toString(),
        department: j['department']?.toString(),
        phone: j['phone']?.toString(),
        lastLogin: j['last_login']?.toString(),
        createdAt: j['created_at']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'username': username,
        'role': role,
        'full_name': fullName,
        'department': department,
        'phone': phone,
        'last_login': lastLogin,
        'created_at': createdAt,
      };
}

/// Result of POST /api/auth/login or /setup: a token plus the user profile.
class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final User user;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        token: (j['token'] ?? '').toString(),
        user: User.fromJson((j['user'] ?? const {}) as Map<String, dynamic>),
      );
}
