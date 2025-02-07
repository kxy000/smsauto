import 'package:permission_handler/permission_handler.dart';

class PermissionUtil {
  static Future<bool> requestSmsPermission() async {
    // 检查是否已经获取权限
    var status = await Permission.sms.status;
    if (status.isGranted) {
      return true;
    }

    // 请求权限
    status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<bool> checkSmsPermission() async {
    return await Permission.sms.status.isGranted;
  }
}
