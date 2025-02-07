import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xinmeisms/models/sms_model.dart';
import 'package:xinmeisms/services/device_service.dart';
import '../config/app_config.dart';

class ApiService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final DeviceService _deviceService = DeviceService();
  final List<Function(String)> _errorListeners = [];
  Timer? _reconnectTimer;
  static const _reconnectInterval = Duration(seconds: 5);
  final _sentMessages = <String>{};
  static const _maxCacheSize = AppConfig.defaultMaxSmsCount;
  Timer? _fullSyncTimer;
  static const _fullSyncInterval = Duration(hours: 1);

  void addErrorListener(Function(String) listener) {
    _errorListeners.add(listener);
  }

  void _notifyError(String message) {
    for (var listener in _errorListeners) {
      listener(message);
    }
  }

  Future<bool> _initializeWebSocket() async {
    if (_isConnected) return true;

    try {
      debugPrint('正在连接 WebSocket: ${AppConfig.defaultApiUrl}');
      final wsUrl = AppConfig.defaultApiUrl;

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel?.stream.listen(
        (message) {
          debugPrint('收到服务器消息: $message');
          _isConnected = true;
        },
        onError: (error) {
          debugPrint('WebSocket 错误: $error');
          _notifyError('WebSocket 连接错误: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('WebSocket 连接已关闭');
          _notifyError('WebSocket 连接已关闭');
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      _isConnected = true;
      _cancelReconnectTimer();
      debugPrint('WebSocket 连接已建立');
      return true;
    } catch (e) {
      debugPrint('WebSocket 连接失败: $e');
      _notifyError('WebSocket 连接失败: $e');
      _handleDisconnect();
      return false;
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _cancelReconnectTimer();
    _reconnectTimer = Timer(_reconnectInterval, () {
      if (!_isConnected) {
        debugPrint('尝试重新连接...');
        _initializeWebSocket();
      }
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> initialize() async {
    await _initializeWebSocket();
    _startFullSync();
  }

  void _startFullSync() {
    _fullSyncTimer?.cancel();
    _fullSyncTimer =
        Timer.periodic(_fullSyncInterval, (_) => _performFullSync());
  }

  Future<void> _performFullSync() async {
    debugPrint('开始全量同步...');
    _sentMessages.clear();
  }

  Future<bool> sendSmsToApi(SmsMessage message) async {
    try {
      int messageId = int.tryParse(message.id) ?? 0;
      if (messageId > 0 &&
          messageId <= (_maxCacheSize - AppConfig.defaultMaxSmsCount)) {
        debugPrint('消息 ${message.id} 超出保存范围，跳过发送');
        return true;
      }

      if (_sentMessages.contains(message.id)) {
        debugPrint('消息 ${message.id} 已发送过，跳过');
        return true;
      }

      if (!_isConnected) {
        debugPrint('WebSocket 未连接，尝试重新连接...');
        final connected = await _initializeWebSocket();
        if (!connected) {
          debugPrint('WebSocket 连接失败，消息将被丢弃');
          return false;
        }
      }

      final deviceId = await _deviceService.getDeviceId();
      final data = {
        'type': 'sms',
        'deviceId': deviceId,
        'data': {
          'sender': message.sender,
          'content': message.content,
          'timestamp': message.timestamp.toIso8601String(),
          'receiverNumber': message.receiverNumber,
          'simSlot': message.simSlot,
          'simDisplayName': message.simDisplayName,
        }
      };

      final jsonString = jsonEncode(data);
      debugPrint('发送消息到服务器: $jsonString');
      _channel?.sink.add(jsonString);

      _sentMessages.add(message.id);
      if (_sentMessages.length > _maxCacheSize) {
        _sentMessages.remove(_sentMessages.first);
      }

      debugPrint('消息发送成功');
      return true;
    } catch (e) {
      debugPrint('发送消息失败: $e');
      _notifyError('发送消息失败: $e');
      return false;
    }
  }

  void dispose() {
    _fullSyncTimer?.cancel();
    _cancelReconnectTimer();
    _channel?.sink.close();
    _isConnected = false;
  }
}
