import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../domain/models/alert.dart';
import '../../domain/models/json_util.dart';
import '../../domain/models/reading.dart';
import '../../features/auth/session.dart';
import 'realtime_snapshot.dart';

/// Drives the live snapshot. Default transport is REST polling (Vercel-safe);
/// `REALTIME_TRANSPORT=ws` additionally opens a WebSocket and merges
/// `sensor_update` / alert messages, with periodic REST reconciliation.
class RealtimeController extends Notifier<RealtimeSnapshot> {
  Timer? _pollTimer;
  Timer? _alertTimer;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  bool _disposed = false;

  @override
  RealtimeSnapshot build() {
    ref.onDispose(_teardown);

    // Only run while authenticated; restart when auth state flips.
    final authed = ref.watch(
      sessionProvider.select((s) => s.isAuthenticated),
    );
    if (authed) {
      Future.microtask(_start);
    }
    return const RealtimeSnapshot();
  }

  Future<void> _start() async {
    if (_disposed) return;
    await refresh();
    if (AppConfig.useWebSocket) {
      _connectWs();
      // Reconcile active alerts periodically even on WS.
      _alertTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _refreshAlerts(),
      );
    } else {
      _pollTimer = Timer.periodic(
        Duration(seconds: AppConfig.pollIntervalSeconds),
        (_) => refresh(),
      );
    }
  }

  /// Full REST refresh of latest readings + active alerts.
  Future<void> refresh() async {
    if (_disposed) return;
    try {
      final sensors = ref.read(sensorRepositoryProvider);
      final alerts = ref.read(alertRepositoryProvider);
      final results = await Future.wait([
        sensors.latest(),
        alerts.active(),
      ]);
      final latestList = results[0] as List<LatestReading>;
      final activeList = results[1] as List<Alert>;
      final map = {for (final r in latestList) r.sensorId: r};
      state = state.copyWith(
        latest: map,
        activeAlerts: activeList,
        updatedAt: DateTime.now(),
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _refreshAlerts() async {
    if (_disposed) return;
    try {
      final list = await ref.read(alertRepositoryProvider).active();
      state = state.copyWith(activeAlerts: list);
    } catch (_) {/* keep last good */}
  }

  void _connectWs() {
    try {
      final channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
      _channel = channel;
      _wsSub = channel.stream.listen(
        _onWsMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
      );
      state = state.copyWith(connected: true);
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    state = state.copyWith(connected: false);
    _wsSub?.cancel();
    _channel?.sink.close();
    _channel = null;
    Timer(const Duration(seconds: 5), () {
      if (!_disposed && AppConfig.useWebSocket) _connectWs();
    });
  }

  void _onWsMessage(dynamic raw) {
    if (_disposed) return;
    try {
      final msg = asMap(jsonDecode(raw.toString()));
      if (msg['type'] != 'sensor_update') return;
      final sensorType = (msg['sensor_type'] ?? '').toString();
      if (sensorType == 'alert') {
        // Alert pushed over WS — pull the authoritative active list.
        _refreshAlerts();
        return;
      }
      final sensorId = (msg['sensor_id'] ?? '').toString();
      if (sensorId.isEmpty) return;
      final payload = asMap(msg['payload']);
      final updated = LatestReading.fromJson({
        'sensor_id': sensorId,
        'sensor_type': sensorType,
        'value_json': payload,
        'reading_ts': payload['timestamp'],
      });
      final newMap = Map<String, LatestReading>.from(state.latest);
      newMap[sensorId] = updated;
      state = state.copyWith(
        latest: newMap,
        updatedAt: DateTime.now(),
        connected: true,
        clearError: true,
      );
    } catch (_) {/* ignore malformed frames */}
  }

  void _teardown() {
    _disposed = true;
    _pollTimer?.cancel();
    _alertTimer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
  }
}

final realtimeProvider =
    NotifierProvider<RealtimeController, RealtimeSnapshot>(
        RealtimeController.new);
