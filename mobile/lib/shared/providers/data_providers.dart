import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/models/alert.dart';
import '../../domain/models/reading.dart';
import '../../domain/models/sensor.dart';
import '../../domain/models/user.dart';

/// Registered sensors.
final sensorsProvider = FutureProvider.autoDispose<List<Sensor>>(
  (ref) => ref.watch(sensorRepositoryProvider).list(),
);

/// Parameters for a readings history query.
@immutable
class ReadingsQuery {
  const ReadingsQuery({
    this.sensorId,
    this.sensorType,
    this.hours = 24,
    this.limit = 1000,
  });

  final String? sensorId;
  final String? sensorType;
  final int hours;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is ReadingsQuery &&
      other.sensorId == sensorId &&
      other.sensorType == sensorType &&
      other.hours == hours &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(sensorId, sensorType, hours, limit);
}

final readingsProvider =
    FutureProvider.autoDispose.family<List<Reading>, ReadingsQuery>(
  (ref, q) {
    final from = DateTime.now().subtract(Duration(hours: q.hours));
    return ref.watch(readingRepositoryProvider).query(
          sensorId: q.sensorId,
          sensorType: q.sensorType,
          from: from,
          limit: q.limit,
        );
  },
);

/// Alert history filter.
@immutable
class AlertHistoryQuery {
  const AlertHistoryQuery({this.severity, this.hours = 168});
  final String? severity;
  final int hours;

  @override
  bool operator ==(Object other) =>
      other is AlertHistoryQuery &&
      other.severity == severity &&
      other.hours == hours;

  @override
  int get hashCode => Object.hash(severity, hours);
}

final alertHistoryProvider =
    FutureProvider.autoDispose.family<List<Alert>, AlertHistoryQuery>(
  (ref, q) {
    final from = DateTime.now().subtract(Duration(hours: q.hours));
    return ref.watch(alertRepositoryProvider).history(
          from: from,
          severity: q.severity,
          limit: 200,
        );
  },
);

final alertRulesProvider = FutureProvider.autoDispose<List<AlertRule>>(
  (ref) => ref.watch(alertRepositoryProvider).rules(),
);

final usersProvider = FutureProvider.autoDispose<List<User>>(
  (ref) => ref.watch(authRepositoryProvider).users(),
);

final settingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(settingsRepositoryProvider).getAll(),
);
