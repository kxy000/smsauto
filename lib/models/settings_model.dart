import '../config/app_config.dart';

class AppSettings {
  final int smsRefreshInterval;
  final String apiUrl;
  final int maxSmsCount;

  AppSettings({
    this.smsRefreshInterval = AppConfig.defaultSmsRefreshInterval,
    this.apiUrl = AppConfig.defaultApiUrl,
    this.maxSmsCount = AppConfig.defaultMaxSmsCount,
  });

  Map<String, dynamic> toJson() => {
        'smsRefreshInterval': smsRefreshInterval,
        'apiUrl': apiUrl,
        'maxSmsCount': maxSmsCount,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      smsRefreshInterval:
          json['smsRefreshInterval'] ?? AppConfig.defaultSmsRefreshInterval,
      apiUrl: json['apiUrl'] ?? AppConfig.defaultApiUrl,
      maxSmsCount: json['maxSmsCount'] ?? AppConfig.defaultMaxSmsCount,
    );
  }
}
