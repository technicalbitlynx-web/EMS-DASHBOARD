import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/alert_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/reading_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/sensor_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../features/auth/session.dart';
import 'config/app_config.dart';
import 'network/api_client.dart';
import 'storage/prefs_store.dart';
import 'storage/token_store.dart';

/// Overridden at startup with the resolved SharedPreferences-backed instance.
final prefsStoreProvider = Provider<PrefsStore>(
  (ref) => throw UnimplementedError('prefsStoreProvider must be overridden'),
);

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Resolved API base URL: runtime override (Settings) falls back to compile-time.
final baseUrlProvider = Provider<String>((ref) {
  final override = ref.watch(prefsStoreProvider).baseUrlOverride;
  return (override != null && override.isNotEmpty)
      ? override
      : AppConfig.apiBaseUrl;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: ref.watch(baseUrlProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    onUnauthorized: () {
      // Lazy read — avoids a build-time cycle with sessionProvider.
      ref.read(sessionProvider.notifier).onTokenExpired();
    },
  );
  return client;
});

// ── Repositories ─────────────────────────────────────────────────
final authRepositoryProvider =
    Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));
final sensorRepositoryProvider =
    Provider((ref) => SensorRepository(ref.watch(apiClientProvider)));
final readingRepositoryProvider =
    Provider((ref) => ReadingRepository(ref.watch(apiClientProvider)));
final alertRepositoryProvider =
    Provider((ref) => AlertRepository(ref.watch(apiClientProvider)));
final reportRepositoryProvider =
    Provider((ref) => ReportRepository(ref.watch(apiClientProvider)));
final settingsRepositoryProvider =
    Provider((ref) => SettingsRepository(ref.watch(apiClientProvider)));
final deviceRepositoryProvider =
    Provider((ref) => DeviceRepository(ref.watch(apiClientProvider)));
