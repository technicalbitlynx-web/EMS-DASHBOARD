import 'json_util.dart';

/// A historical sensor reading (GET /api/readings).
class Reading {
  const Reading({
    required this.sensorId,
    required this.sensorType,
    required this.readingTs,
    this.id,
    this.valueNumeric,
    this.valueJson = const {},
    this.unit,
    this.sensorName,
    this.location,
    this.zone,
  });

  final int? id;
  final String sensorId;
  final String sensorType;
  final String readingTs;
  final double? valueNumeric;
  final Map<String, dynamic> valueJson;
  final String? unit;
  final String? sensorName;
  final String? location;
  final String? zone;

  factory Reading.fromJson(Map<String, dynamic> j) => Reading(
        id: asInt(j['id']),
        sensorId: (j['sensor_id'] ?? '').toString(),
        sensorType: (j['sensor_type'] ?? '').toString(),
        readingTs: (j['reading_ts'] ?? '').toString(),
        valueNumeric: asDouble(j['value_numeric']),
        valueJson: asMap(j['value_json']),
        unit: j['unit']?.toString(),
        sensorName: j['sensor_name']?.toString(),
        location: j['location']?.toString(),
        zone: j['zone']?.toString(),
      );
}

/// The latest reading for a sensor (GET /api/sensors/latest), which the web
/// dashboard joins with sensor metadata.
class LatestReading {
  const LatestReading({
    required this.sensorId,
    required this.sensorType,
    this.name,
    this.location,
    this.zone,
    this.unit,
    this.readingTs,
    this.valueNumeric,
    this.valueJson = const {},
    this.enabled = true,
    this.thresholds,
  });

  final String sensorId;
  final String sensorType;
  final String? name;
  final String? location;
  final String? zone;
  final String? unit;
  final String? readingTs;
  final double? valueNumeric;
  final Map<String, dynamic> valueJson;
  final bool enabled;
  final Map<String, dynamic>? thresholds;

  /// Derived status string ('normal'|'warning'|'critical') from value_json.
  String get status => (valueJson['status'] ?? 'unknown').toString();

  // Convenience typed accessors for the per-type payloads (simulator shapes).
  double? get tempC => asDouble(valueJson['temp_c']);
  double? get humidityPct => asDouble(valueJson['humidity_pct']);
  double? get voltageV => asDouble(valueJson['voltage_v']);
  double? get currentA => asDouble(valueJson['current_a']);
  double? get powerFactor => asDouble(valueJson['power_factor']);
  double? get powerW => asDouble(valueJson['power_w']);
  double? get energyKwh => asDouble(valueJson['energy_kwh']);
  double? get smokeLevelPct => asDouble(valueJson['level_pct']);
  bool get smokeAlarm => asBool(valueJson['alarm']);
  bool get doorOpen => asBool(valueJson['is_open']);
  String? get doorState => valueJson['state']?.toString();
  bool get dehumidifierOn => asBool(valueJson['is_on']);

  factory LatestReading.fromJson(Map<String, dynamic> j) => LatestReading(
        sensorId: (j['sensor_id'] ?? j['id'] ?? '').toString(),
        sensorType: (j['sensor_type'] ?? j['type'] ?? '').toString(),
        name: j['name']?.toString() ?? j['sensor_name']?.toString(),
        location: j['location']?.toString(),
        zone: j['zone']?.toString(),
        unit: j['unit']?.toString(),
        readingTs: (j['reading_ts'] ?? j['timestamp'])?.toString(),
        valueNumeric: asDouble(j['value_numeric']),
        valueJson: asMap(j['value_json']),
        enabled: j['enabled'] == null ? true : asBool(j['enabled']),
        thresholds:
            j['thresholds'] == null ? null : asMap(j['thresholds']),
      );
}

/// Aggregated stats per sensor (GET /api/readings/summary).
class ReadingSummary {
  const ReadingSummary({
    required this.sensorId,
    required this.sensorType,
    this.name,
    this.location,
    this.minVal,
    this.maxVal,
    this.avgVal,
    this.readingCount,
    this.lastReading,
  });

  final String sensorId;
  final String sensorType;
  final String? name;
  final String? location;
  final double? minVal;
  final double? maxVal;
  final double? avgVal;
  final int? readingCount;
  final String? lastReading;

  factory ReadingSummary.fromJson(Map<String, dynamic> j) => ReadingSummary(
        sensorId: (j['sensor_id'] ?? '').toString(),
        sensorType: (j['sensor_type'] ?? '').toString(),
        name: j['sensor_name']?.toString() ?? j['name']?.toString(),
        location: j['location']?.toString(),
        minVal: asDouble(j['min_val'] ?? j['min']),
        maxVal: asDouble(j['max_val'] ?? j['max']),
        avgVal: asDouble(j['avg_val'] ?? j['avg']),
        readingCount: asInt(j['reading_count'] ?? j['count']),
        lastReading: (j['last_reading'] ?? j['last_ts'])?.toString(),
      );
}
