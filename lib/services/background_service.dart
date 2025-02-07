import 'package:workmanager/workmanager.dart';
import 'sms_service.dart';
import 'settings_service.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'sms_sync':
        try {
          final smsService = SmsService();
          final messages = await smsService.getMessages(limit: 20);
          debugPrint('Background sync: ${messages.length} messages');
        } catch (e) {
          debugPrint('Background task failed: $e');
        }
        break;
    }
    return true;
  });
}

Future<void> initializeBackgroundService() async {
  await Workmanager().initialize(callbackDispatcher);
  await startBackgroundService();
}

Future<void> startBackgroundService() async {
  final settings = await SettingsService().getSettings();

  await Workmanager().registerPeriodicTask(
    'sms_sync',
    'sms_sync',
    frequency: Duration(seconds: settings.smsRefreshInterval),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}
