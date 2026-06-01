import 'json_util.dart';

/// Sensor types known to the EMS backend.
class SensorTypes {
  static const temperature = 'temperature';
  static const power = 'power';
  static const door = 'door';
  static const smoke = 'smoke';
  static const dehumidifier = 'dehumidifier';

  static const all = [temperature, power, door, smoke, dehumidifier];
}

/// A registered sensor (GET /api/sensors, /sensors/:id).
class Sensor {
  const Sensor({
    required this.id,
    required this.type,
    required this.name,
    this.location,
    this.zone,
    this.mqttTopic,
    this.thresholds,
    this.enabled = true,
    this.createdAt,
  });

  final String id;
  final String type;
  final String name;
  final String? location;
  final String? zone;
  final String? mqttTopic;
  final Map<String, dynamic>? thresholds;
  final bool enabled;
  final String? createdAt;

  factory Sensor.fromJson(Map<String, dynamic> j) => Sensor(
        id: (j['id'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        name: (j['name'] ?? j['id'] ?? '').toString(),
        location: j['location']?.toString(),
        zone: j['zone']?.toString(),
        mqttTopic: j['mqtt_topic']?.toString(),
        thresholds:
            j['thresholds'] == null ? null : asMap(j['thresholds']),
        enabled: j['enabled'] == null ? true : asBool(j['enabled']),
        createdAt: j['created_at']?.toString(),
      );
}
