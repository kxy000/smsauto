import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionUtil {
  static Future<bool> checkPhonePermission(BuildContext context) async {
    if (await Permission.phone.isGranted) {
      return true;
    }

    // 显示解释对话框
    if (!context.mounted) return false;
    final bool shouldRequest = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要电话权限'),
            content: const Text('为了区分不同设备发送的短信，我们需要获取SIM卡号码。\n\n这不会泄露您的隐私信息。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('授权'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldRequest) {
      final status = await Permission.phone.request();
      return status.isGranted;
    }

    return false;
  }

  static Future<Map<Permission, String>> checkAllPermissions() async {
    return {
      Permission.phone: await Permission.phone.status
          .then((status) => _getStatusText(status)),
      Permission.sms:
          await Permission.sms.status.then((status) => _getStatusText(status)),
    };
  }

  static String _getStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '已授权';
      case PermissionStatus.denied:
        return '未授权';
      case PermissionStatus.permanentlyDenied:
        return '永久拒绝';
      case PermissionStatus.restricted:
        return '受限';
      case PermissionStatus.limited:
        return '部分授权';
      default:
        return '未知状态';
    }
  }
}
