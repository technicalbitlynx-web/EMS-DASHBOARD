import '../../core/network/api_client.dart';
import '../../domain/models/json_util.dart';

class SettingsRepository {
  SettingsRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> getAll() async {
    final data = await _api.getJson('/api/settings');
    return asMap(data);
  }

  Future<dynamic> get(String key) => _api.getJson('/api/settings/$key');

  Future<void> put(String key, Object value) =>
      _api.putJson('/api/settings/$key', body: value);

  Future<void> applyRetention() =>
      _api.postJson('/api/settings/retention/apply');
}
