import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive persisted preferences (theme, base-url override).
class PrefsStore {
  PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kThemeMode = 'ems_theme'; // 'light' | 'dark' | 'system'
  static const _kBaseUrlOverride = 'ems_base_url';

  static Future<PrefsStore> create() async =>
      PrefsStore(await SharedPreferences.getInstance());

  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) => _prefs.setString(_kThemeMode, mode);

  /// Optional runtime override of the API base URL (Settings screen). When
  /// null/empty the compile-time AppConfig.apiBaseUrl is used.
  String? get baseUrlOverride {
    final v = _prefs.getString(_kBaseUrlOverride);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setBaseUrlOverride(String? url) async {
    if (url == null || url.isEmpty) {
      await _prefs.remove(_kBaseUrlOverride);
    } else {
      await _prefs.setString(_kBaseUrlOverride, url);
    }
  }
}
