import 'json_util.dart';
import 'reading.dart';

/// Summary report payload (GET /api/reports/summary-json) used to build a
/// native PDF on the device (replacing the web jsPDF flow).
class SummaryReport {
  const SummaryReport({
    this.generatedAt,
    this.from,
    this.to,
    this.sensors = const [],
    this.readingsSummary = const [],
    this.alertsSummary = const [],
  });

  final String? generatedAt;
  final String? from;
  final String? to;
  final List<Map<String, dynamic>> sensors;
  final List<ReadingSummary> readingsSummary;
  final List<AlertCount> alertsSummary;

  factory SummaryReport.fromJson(Map<String, dynamic> j) {
    final period = asMap(j['period']);
    return SummaryReport(
      generatedAt: j['generated_at']?.toString(),
      from: period['from']?.toString() ?? j['from']?.toString(),
      to: period['to']?.toString() ?? j['to']?.toString(),
      sensors: (j['sensors'] as List? ?? [])
          .map((e) => asMap(e))
          .toList(growable: false),
      readingsSummary: (j['readings_summary'] as List? ?? [])
          .map((e) => ReadingSummary.fromJson(asMap(e)))
          .toList(growable: false),
      alertsSummary: (j['alerts_summary'] as List? ?? [])
          .map((e) => AlertCount.fromJson(asMap(e)))
          .toList(growable: false),
    );
  }
}

class AlertCount {
  const AlertCount({required this.severity, required this.count});

  final String severity;
  final int count;

  factory AlertCount.fromJson(Map<String, dynamic> j) => AlertCount(
        severity: (j['severity'] ?? '').toString(),
        count: asInt(j['count']) ?? 0,
      );
}
