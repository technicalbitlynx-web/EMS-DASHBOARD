import '../../core/network/api_client.dart';

/// Registers/unregisters this device's FCM token for push notifications.
class DeviceRepository {
  DeviceRepository(this._api);
  final ApiClient _api;

  Future<void> register(String token, {String platform = 'android'}) =>
      _api.postJson('/api/devices/register',
          body: {'token': token, 'platform': platform});

  Future<void> unregister(String token) =>
      _api.delete('/api/devices/$token');
}
