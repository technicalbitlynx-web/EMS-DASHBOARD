import '../../core/network/api_client.dart';
import '../../domain/models/json_util.dart';
import '../../domain/models/report.dart';

class ReportRepository {
  ReportRepository(this._api);
  final ApiClient _api;

  Future<List<int>> readingsCsv({
    String? sensorType,
    String? sensorId,
    DateTime? from,
    DateTime? to,
  }) {
    return _api.getBytes('/api/reports/csv', query: {
      if (sensorType != null) 'sensor_type': sensorType,
      if (sensorId != null) 'sensor_id': sensorId,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    });
  }

  Future<List<int>> alertsCsv({
    DateTime? from,
    DateTime? to,
    String? severity,
  }) {
    return _api.getBytes('/api/reports/alerts-csv', query: {
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      if (severity != null) 'severity': severity,
    });
  }

  Future<SummaryReport> summary({DateTime? from, DateTime? to}) async {
    final data = await _api.getJson('/api/reports/summary-json', query: {
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    });
    return SummaryReport.fromJson(asMap(data));
  }
}
