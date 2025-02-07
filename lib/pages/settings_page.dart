import 'package:flutter/material.dart';
import '../models/settings_model.dart';
import '../services/settings_service.dart';
import '../config/app_config.dart';
import '../services/device_service.dart';
import '../utils/permission_util.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService();
  final DeviceService _deviceService = DeviceService();
  late AppSettings _settings;
  final _intervalController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _maxSmsCountController = TextEditingController();
  Map<Permission, String> _permissionStatus = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPermissionStatus();
  }

  Future<void> _loadSettings() async {
    _settings = await _settingsService.getSettings();
    _intervalController.text = _settings.smsRefreshInterval.toString();
    _apiUrlController.text = _settings.apiUrl;
    _maxSmsCountController.text = _settings.maxSmsCount.toString();
    setState(() {});
  }

  Future<void> _loadPermissionStatus() async {
    final status = await PermissionUtil.checkAllPermissions();
    setState(() {
      _permissionStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _intervalController,
              decoration: const InputDecoration(
                labelText: '短信刷新间隔（秒）',
                helperText: '建议设置 5-30 秒之间',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiUrlController,
              decoration: const InputDecoration(
                labelText: 'API地址',
                helperText: '短信将推送到此地址',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _maxSmsCountController,
              decoration: const InputDecoration(
                labelText: '保留短信数量',
                helperText: '超过此数量将自动删除旧短信',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            const Text('权限状态',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildPermissionItem(
                '电话权限', _permissionStatus[Permission.phone] ?? '未知'),
            _buildPermissionItem(
                '短信权限', _permissionStatus[Permission.sms] ?? '未知'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final interval = int.tryParse(_intervalController.text) ??
                    AppConfig.defaultSmsRefreshInterval;
                final maxCount = int.tryParse(_maxSmsCountController.text) ??
                    AppConfig.defaultMaxSmsCount;

                await _settingsService.saveSettings(AppSettings(
                  smsRefreshInterval: interval,
                  apiUrl: _apiUrlController.text.trim(),
                  maxSmsCount: maxCount,
                ));

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('设置已保存')),
                );
                Navigator.pop(context, true);
              },
              child: const Text('保存设置'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (await PermissionUtil.checkPhonePermission(context)) {
                  final numbers = await _deviceService.getSimNumbers();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('SIM卡号码: ${numbers.join(", ")}')),
                  );
                }
                _loadPermissionStatus(); // 刷新权限状态
              },
              child: const Text('测试获取SIM卡号码'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem(String name, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == '已授权' ? Colors.green[100] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: status == '已授权' ? Colors.green[900] : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
