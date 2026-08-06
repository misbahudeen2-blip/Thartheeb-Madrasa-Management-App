import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestAllPermissions() async {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
      
      // Request other needed permissions here without crashing
      // E.g., camera, storage, etc.
    } catch (e) {
      // Ignore errors to prevent crashes/black screens
      print('Permission request error: $e');
    }
  }
}
