import '../../core/network/api_client.dart';
import '../../domain/models/json_util.dart';
import '../../domain/models/reading.dart';

class ReadingRepository {
  ReadingRepository(this._api);
  final ApiClient _api;

  Future<List<Reading>> query({
    String? sensorId,
    String? sensorType,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final q = <String, dynamic>{
      if (sensorId != null) 'sensor_id': sensorId,
      if (sensorType != null) 'sensor_type': sensorType,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      if (limit != null) 'limit': limit,
    };
    final data = await _api.getJson('/api/readings', query: q);
    if (data is List) return data.map((e) => Reading.fromJson(asMap(e))).toList();
    if (data is Map && data['rows'] is List) {
      return (data['rows'] as List)
          .map((e) => Reading.fromJson(asMap(e)))
          .toList();
    }
    return const [];
  }

  Future<List<ReadingSummary>> summary({
    String? sensorType,
    DateTime? from,
    DateTime? to,
  }) async {
    final q = <String, dynamic>{
      if (sensorType != null) 'sensor_type': sensorType,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    final data = await _api.getJson('/api/readings/summary', query: q);
    if (data is List) {
      return data.map((e) => ReadingSummary.fromJson(asMap(e))).toList();
    }
    return const [];
  }
}
