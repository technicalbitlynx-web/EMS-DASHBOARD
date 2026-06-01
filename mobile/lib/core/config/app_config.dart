/// Application configuration, supplied at build time via --dart-define.
///
/// Example:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3002
///   flutter build apk --release --dart-define=API_BASE_URL=https://your.vercel.app
class AppConfig {
  const AppConfig._();

  /// Base URL of the EMS backend. Defaults to the Android-emulator loopback
  /// (`10.0.2.2`) pointing at the locally running backend on port 3002.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3002',
  );

  /// Realtime transport: `polling` (default, Vercel-safe) or `ws`
  /// (only works against a persistent host such as DigitalOcean).
  static const String realtimeTransport = String.fromEnvironment(
    'REALTIME_TRANSPORT',
    defaultValue: 'polling',
  );

  /// Polling cadence in seconds for the polling realtime transport.
  static const int pollIntervalSeconds = int.fromEnvironment(
    'POLL_INTERVAL_SECONDS',
    defaultValue: 15,
  );

  /// Whether Firebase / FCM push is enabled in this build. Disabled by default
  /// so the app runs without a google-services.json during early development.
  static const bool enablePush = bool.fromEnvironment(
    'ENABLE_PUSH',
    defaultValue: false,
  );

  static bool get useWebSocket => realtimeTransport.toLowerCase() == 'ws';

  /// WebSocket URL derived from [apiBaseUrl] (http->ws, https->wss).
  static String get wsUrl {
    final base = Uri.parse(apiBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/ws',
    ).toString();
  }
}
