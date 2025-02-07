import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SimCardInfo {
  final int slotIndex;
  final int subscriptionId;
  final String number;
  final String displayName;

  SimCardInfo({
    required this.slotIndex,
    required this.subscriptionId,
    required this.number,
    required this.displayName,
  });

  @override
  String toString() => '$displayName ($number)';
}

class DeviceService {
  static const platform = MethodChannel('com.nmg.xinmeisms/device');
  List<SimCardInfo>? _cachedSimCards;

  Future<String> getDeviceId() async {
    try {
      final String result = await platform.invokeMethod('getDeviceId');
      return result;
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      return 'unknown';
    }
  }

  Future<List<SimCardInfo>> getSimNumbers() async {
    if (_cachedSimCards != null) {
      return _cachedSimCards!;
    }

    try {
      final List<dynamic> result = await platform.invokeMethod('getSimInfo');
      _cachedSimCards = result
          .map((info) => SimCardInfo(
                slotIndex: info['slotIndex'] as int,
                subscriptionId: info['subscriptionId'] as int,
                number: info['number'] as String,
                displayName: info['displayName'] as String,
              ))
          .toList();

      return _cachedSimCards!;
    } catch (e) {
      debugPrint('Error getting SIM info: $e');
      return [];
    }
  }

  void clearCache() {
    _cachedSimCards = null;
  }
}
