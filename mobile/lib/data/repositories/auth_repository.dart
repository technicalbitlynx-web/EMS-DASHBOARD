import '../../core/network/api_client.dart';
import '../../domain/models/json_util.dart';
import '../../domain/models/user.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<AuthResult> login(String identifier, String password) async {
    final data = await _api.postJson('/api/auth/login', body: {
      'identifier': identifier,
      'password': password,
    });
    return AuthResult.fromJson(asMap(data));
  }

  Future<AuthResult> setup({
    required String email,
    required String username,
    required String password,
    String? fullName,
  }) async {
    final data = await _api.postJson('/api/auth/setup', body: {
      'email': email,
      'username': username,
      'password': password,
      if (fullName != null) 'full_name': fullName,
    });
    return AuthResult.fromJson(asMap(data));
  }

  Future<User> me() async {
    final data = await _api.getJson('/api/auth/me');
    return User.fromJson(asMap(data));
  }

  Future<List<String>> loginHistory() async {
    final data = await _api.getJson('/api/auth/login-history');
    if (data is List) return data.map((e) => e.toString()).toList();
    return const [];
  }

  Future<List<User>> users() async {
    final data = await _api.getJson('/api/auth/users');
    if (data is List) return data.map((e) => User.fromJson(asMap(e))).toList();
    return const [];
  }

  Future<void> register(Map<String, dynamic> body) =>
      _api.postJson('/api/auth/register', body: body);

  Future<void> updateUser(String email, Map<String, dynamic> body) =>
      _api.putJson('/api/auth/users/$email', body: body);

  Future<void> deleteUser(String email) =>
      _api.delete('/api/auth/users/$email');
}
