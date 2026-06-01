import '../../core/network/api_client.dart';
import '../../domain/models/alert.dart';
import '../../domain/models/json_util.dart';

class AlertRepository {
  AlertRepository(this._api);
  final ApiClient _api;

  Future<List<Alert>> active() async {
    final data = await _api.getJson('/api/alerts/active');
    if (data is List) return data.map((e) => Alert.fromJson(asMap(e))).toList();
    return const [];
  }

  Future<List<Alert>> history({
    DateTime? from,
    DateTime? to,
    String? severity,
    String? sensorId,
    int? limit,
    int? offset,
  }) async {
    final q = <String, dynamic>{
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      if (severity != null) 'severity': severity,
      if (sensorId != null) 'sensor_id': sensorId,
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
    };
    final data = await _api.getJson('/api/alerts/history', query: q);
    if (data is List) return data.map((e) => Alert.fromJson(asMap(e))).toList();
    if (data is Map && data['rows'] is List) {
      return (data['rows'] as List).map((e) => Alert.fromJson(asMap(e))).toList();
    }
    return const [];
  }

  Future<void> acknowledge(int id) =>
      _api.putJson('/api/alerts/$id/acknowledge');

  Future<List<AlertRule>> rules() async {
    final data = await _api.getJson('/api/alerts/rules');
    if (data is List) {
      return data.map((e) => AlertRule.fromJson(asMap(e))).toList();
    }
    return const [];
  }

  Future<void> createRule(Map<String, dynamic> body) =>
      _api.postJson('/api/alerts/rules', body: body);

  Future<void> updateRule(int id, Map<String, dynamic> body) =>
      _api.putJson('/api/alerts/rules/$id', body: body);

  Future<void> deleteRule(int id) => _api.delete('/api/alerts/rules/$id');
}
