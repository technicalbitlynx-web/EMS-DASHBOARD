import 'package:flutter/foundation.dart';

import '../../domain/models/alert.dart';
import '../../domain/models/reading.dart';

/// Immutable snapshot of the latest live state, fed by polling or WebSocket.
@immutable
class RealtimeSnapshot {
  const RealtimeSnapshot({
    this.latest = const {},
    this.activeAlerts = const [],
    this.updatedAt,
    this.connected = false,
    this.error,
  });

  /// Latest reading per sensor id.
  final Map<String, LatestReading> latest;
  final List<Alert> activeAlerts;
  final DateTime? updatedAt;
  final bool connected;
  final String? error;

  int get criticalCount =>
      activeAlerts.where((a) => a.isCritical).length;
  int get warningCount =>
      activeAlerts.where((a) => !a.isCritical).length;

  RealtimeSnapshot copyWith({
    Map<String, LatestReading>? latest,
    List<Alert>? activeAlerts,
    DateTime? updatedAt,
    bool? connected,
    String? error,
    bool clearError = false,
  }) {
    return RealtimeSnapshot(
      latest: latest ?? this.latest,
      activeAlerts: activeAlerts ?? this.activeAlerts,
      updatedAt: updatedAt ?? this.updatedAt,
      connected: connected ?? this.connected,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
