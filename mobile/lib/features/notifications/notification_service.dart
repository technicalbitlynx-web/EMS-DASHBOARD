import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';

/// Top-level background handler (required by FCM to be a static/top-level fn).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // No heavy work here; the OS displays the notification from the `notification`
  // payload. Data-only messages could be persisted if needed.
}

/// Wraps Firebase Cloud Messaging. All Firebase calls are gated behind
/// [AppConfig.enablePush] so the app runs without google-services.json.
class NotificationService {
  NotificationService(this._ref);
  final Ref _ref;

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _lastToken;

  static const _channel = AndroidNotificationChannel(
    'ems_alerts',
    'EMS Alerts',
    description: 'Critical and warning alerts from the server room',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (!AppConfig.enablePush) return;
    try {
      await Firebase.initializeApp();
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (resp) =>
            _handleTapPayload(resp.payload),
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleOpenedMessage(initial);

      FirebaseMessaging.instance.onTokenRefresh.listen(_onToken);
      _ready = true;
    } catch (e) {
      debugPrint('[FCM] init skipped: $e');
    }
  }

  /// Called after login: obtain and register the device token.
  Future<void> registerAfterLogin() async {
    if (!AppConfig.enablePush || !_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _onToken(token);
    } catch (e) {
      debugPrint('[FCM] token registration failed: $e');
    }
  }

  /// Called on logout: best-effort unregister.
  Future<void> unregister() async {
    if (!AppConfig.enablePush || _lastToken == null) return;
    try {
      await _ref.read(deviceRepositoryProvider).unregister(_lastToken!);
    } catch (_) {/* ignore */}
    _lastToken = null;
  }

  Future<void> _onToken(String token) async {
    _lastToken = token;
    try {
      await _ref.read(deviceRepositoryProvider).register(token);
    } catch (e) {
      debugPrint('[FCM] register endpoint failed: $e');
    }
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _local.show(
      id: n.hashCode,
      title: n.title ?? 'EMS Alert',
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['alertId']?.toString(),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) =>
      _handleTapPayload(message.data['alertId']?.toString());

  void _handleTapPayload(String? alertId) {
    if (alertId == null || alertId.isEmpty) return;
    try {
      _ref.read(routerProvider).go('/alerts/$alertId');
    } catch (_) {/* router not ready */}
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService(ref));
