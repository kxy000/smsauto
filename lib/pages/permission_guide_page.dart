import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionGuidePage extends StatefulWidget {
  const PermissionGuidePage({super.key});

  @override
  State<PermissionGuidePage> createState() => _PermissionGuidePageState();
}

class _PermissionGuidePageState extends State<PermissionGuidePage> {
  final List<bool> _completedSteps = [false, false, false];
  String _manufacturer = '';
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _getDeviceInfo();
  }

  Future<void> _getDeviceInfo() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    setState(() {
      _manufacturer = deviceInfo.manufacturer.toLowerCase();
    });
  }

  String _getBatteryOptimizationGuide() {
    switch (_manufacturer) {
      case 'xiaomi':
        return '设置 > 电池和性能 > 省电策略 > 无限制';
      case 'huawei':
        return '设置 > 电池 > 启动管理 > 关闭自动管理';
      case 'oppo':
        return '设置 > 电池 > 高性能模式';
      default:
        return '设置 > 电池 > 电池优化 > 选择"不优化"';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('初始设置'),
        automaticallyImplyLeading: false,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < _completedSteps.length - 1) {
            setState(() {
              _currentStep += 1;
            });
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          }
        },
        controlsBuilder: (context, details) {
          return Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  await AppSettings.openAppSettings();
                  setState(() {
                    _completedSteps[_currentStep] = true;
                    if (_currentStep < _completedSteps.length - 1) {
                      _currentStep += 1;
                    }
                  });
                },
                child: const Text('去设置'),
              ),
              if (_completedSteps[_currentStep])
                TextButton(
                  onPressed: () {
                    setState(() {
                      _completedSteps[_currentStep] = false;
                    });
                  },
                  child: const Text('重新设置'),
                ),
            ],
          );
        },
        steps: [
          Step(
            title: const Text('短信权限'),
            content: const Text('需要获取短信读取权限，以便同步短信内容'),
            isActive: !_completedSteps[0],
            state: _completedSteps[0] ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('电池优化'),
            content: Text('请按照以下路径关闭电池优化：\n${_getBatteryOptimizationGuide()}'),
            isActive: !_completedSteps[1],
            state: _completedSteps[1] ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('自启动权限'),
            content: const Text('请在应用管理中允许应用自启动，确保后台服务正常运行'),
            isActive: !_completedSteps[2],
            state: _completedSteps[2] ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _completedSteps.every((step) => step)
                ? () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('is_first_run', false);

                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacementNamed('/home');
                  }
                : null,
            child: const Text('完成设置'),
          ),
        ),
      ),
    );
  }
}
