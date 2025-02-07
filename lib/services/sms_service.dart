import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart' as inbox;
import '../models/sms_model.dart';
import '../utils/permission_handler.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart';
import '../services/device_service.dart';

class SmsService {
  final inbox.SmsQuery _query = inbox.SmsQuery();
  final ApiService _apiService = ApiService();
  final SettingsService _settingsService = SettingsService();
  final DeviceService _deviceService = DeviceService();
  static const platform = MethodChannel('com.nmg.xinmeisms/sms');

  Future<int> getSmsSubscriptionId(String messageId) async {
    try {
      final int result = await platform.invokeMethod('getSmsSubscriptionId', {
        'messageId': messageId,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('获取短信 SIM 卡信息失败: ${e.message}');
      return -1;
    }
  }

  Future<bool> deleteSms(String messageId) async {
    try {
      final result =
          await platform.invokeMethod('deleteSms', {'id': messageId});
      return result == true;
    } catch (e) {
      debugPrint('删除短信失败: $e');
      return false;
    }
  }

  Future<void> cleanOldMessages(int maxCount) async {
    if (!await PermissionUtil.checkSmsPermission()) {
      throw Exception('SMS permission not granted');
    }

    final messages = await _query.querySms(
      kinds: [inbox.SmsQueryKind.inbox],
      sort: true,
    );

    if (messages.length > maxCount) {
      final messagesToDelete = messages.sublist(maxCount);
      for (var msg in messagesToDelete) {
        if (msg.id != null) {
          final deleted = await deleteSms(msg.id.toString());
          debugPrint('删除消息 ${msg.id}: ${deleted ? '成功' : '失败'}');
        }
      }
    }
  }

  Future<List<SmsMessage>> getMessages({int? limit, int offset = 0}) async {
    try {
      if (!await PermissionUtil.checkSmsPermission()) {
        debugPrint('SMS permission not granted');
        return [];
      }

      final settings = await _settingsService.getSettings();
      final simCards = await _deviceService.getSimNumbers();
      await cleanOldMessages(settings.maxSmsCount);

      final messages = await _query.querySms(
        kinds: [inbox.SmsQueryKind.inbox],
        count: limit ?? 20,
        start: offset,
        sort: true,
      );

      debugPrint('获取到 ${messages.length} 条短信');

      final futures = messages.map((msg) async {
        // 获取短信的 SIM 卡信息
        final subId = await getSmsSubscriptionId(msg.id.toString());

        // 根据 subId 匹配对应的 SIM 卡
        final simCard = simCards.firstWhere(
          (sim) => sim.subscriptionId == subId,
          orElse: () => simCards.isNotEmpty
              ? simCards[0]
              : SimCardInfo(
                  slotIndex: -1,
                  subscriptionId: -1,
                  number: '未知',
                  displayName: '未知SIM卡',
                ),
        );

        debugPrint('短信接收信息: {'
            'id: ${msg.id}, '
            'subId: $subId, '
            'matched simCard: ${simCard.displayName}(${simCard.number})'
            '}');

        final smsMessage = SmsMessage(
          id: msg.id?.toString() ?? '',
          sender: msg.address ?? '',
          content: msg.body ?? '',
          timestamp: msg.date ?? DateTime.now(),
          receiverNumber: simCard.number,
          simSlot: simCard.slotIndex,
          simDisplayName: simCard.displayName,
        );

        _apiService.sendSmsToApi(smsMessage);
        return smsMessage;
      });

      return Future.wait(futures);
    } catch (e) {
      debugPrint('获取短信失败: $e');
      return [];
    }
  }

  // 注意：flutter_sms_inbox 不支持直接监听新短信
  // 我们可以通过定期轮询来实现类似功能
  Stream<List<SmsMessage>> streamMessages({int intervalSeconds = 5}) async* {
    while (true) {
      yield await getMessages(limit: 20);
      await Future.delayed(Duration(seconds: intervalSeconds));
    }
  }
}
