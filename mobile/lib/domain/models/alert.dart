import 'json_util.dart';

/// An alert occurrence (GET /api/alerts/active, /alerts/history).
class Alert {
  const Alert({
    required this.id,
    required this.sensorId,
    required this.message,
    required this.severity,
    this.ruleId,
    this.triggeredAt,
    this.resolvedAt,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.sensorName,
    this.location,
  });

  final int id;
  final int? ruleId;
  final String sensorId;
  final String message;
  final String severity; // warning | critical
  final String? triggeredAt;
  final String? resolvedAt;
  final String? acknowledgedBy;
  final String? acknowledgedAt;
  final String? sensorName;
  final String? location;

  bool get isResolved => resolvedAt != null && resolvedAt!.isNotEmpty;
  bool get isAcknowledged =>
      acknowledgedBy != null && acknowledgedBy!.isNotEmpty;
  bool get isCritical => severity.toLowerCase() == 'critical';

  factory Alert.fromJson(Map<String, dynamic> j) => Alert(
        id: asInt(j['id']) ?? 0,
        ruleId: asInt(j['rule_id']),
        sensorId: (j['sensor_id'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        severity: (j['severity'] ?? 'warning').toString(),
        triggeredAt: j['triggered_at']?.toString(),
        resolvedAt: j['resolved_at']?.toString(),
        acknowledgedBy: j['acknowledged_by']?.toString(),
        acknowledgedAt: j['acknowledged_at']?.toString(),
        sensorName: j['sensor_name']?.toString(),
        location: j['location']?.toString(),
      );
}

/// An alert rule (GET /api/alerts/rules).
class AlertRule {
  const AlertRule({
    required this.id,
    required this.sensorId,
    required this.metric,
    required this.operator,
    required this.threshold,
    required this.severity,
    this.enabled = true,
    this.cooldownMinutes,
    this.sensorName,
    this.sensorType,
  });

  final int id;
  final String sensorId;
  final String metric;
  final String operator; // > < >= <= = !=
  final double threshold;
  final String severity;
  final bool enabled;
  final int? cooldownMinutes;
  final String? sensorName;
  final String? sensorType;

  factory AlertRule.fromJson(Map<String, dynamic> j) => AlertRule(
        id: asInt(j['id']) ?? 0,
        sensorId: (j['sensor_id'] ?? '').toString(),
        metric: (j['metric'] ?? '').toString(),
        operator: (j['operator'] ?? '>').toString(),
        threshold: asDouble(j['threshold']) ?? 0,
        severity: (j['severity'] ?? 'warning').toString(),
        enabled: j['enabled'] == null ? true : asBool(j['enabled']),
        cooldownMinutes: asInt(j['cooldown_minutes']),
        sensorName: j['sensor_name']?.toString(),
        sensorType: j['sensor_type']?.toString(),
      );
}
