import '../../core/network/api_client.dart';
import '../../domain/models/json_util.dart';
import '../../domain/models/reading.dart';
import '../../domain/models/sensor.dart';

class SensorRepository {
  SensorRepository(this._api);
  final ApiClient _api;

  Future<List<Sensor>> list() async {
    final data = await _api.getJson('/api/sensors');
    if (data is List) return data.map((e) => Sensor.fromJson(asMap(e))).toList();
    return const [];
  }

  Future<List<LatestReading>> latest() async {
    final data = await _api.getJson('/api/sensors/latest');
    if (data is List) {
      return data.map((e) => LatestReading.fromJson(asMap(e))).toList();
    }
    return const [];
  }

  Future<Sensor> get(String id) async {
    final data = await _api.getJson('/api/sensors/$id');
    return Sensor.fromJson(asMap(data));
  }

  Future<void> create(Map<String, dynamic> body) =>
      _api.postJson('/api/sensors', body: body);

  Future<void> update(String id, Map<String, dynamic> body) =>
      _api.putJson('/api/sensors/$id', body: body);

  Future<void> remove(String id) => _api.delete('/api/sensors/$id');
}
