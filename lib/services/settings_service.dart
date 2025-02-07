import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_model.dart';
import '../config/app_config.dart';

class SettingsService {
  static const String _keyRefreshInterval = 'sms_refresh_interval';
  static const String _keyApiUrl = 'api_url';
  static const String _keyMaxSmsCount = 'max_sms_count';

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRefreshInterval, settings.smsRefreshInterval);
    await prefs.setString(_keyApiUrl, settings.apiUrl);
    await prefs.setInt(_keyMaxSmsCount, settings.maxSmsCount);
  }

  Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      smsRefreshInterval: prefs.getInt(_keyRefreshInterval) ??
          AppConfig.defaultSmsRefreshInterval,
      apiUrl: prefs.getString(_keyApiUrl) ?? AppConfig.defaultApiUrl,
      maxSmsCount:
          prefs.getInt(_keyMaxSmsCount) ?? AppConfig.defaultMaxSmsCount,
    );
  }
}
