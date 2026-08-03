import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) return;
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);
  }

  /// Show native top banner notification
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tartheeb_channel_id',
      'Tartheeb Attendance Alerts',
      channelDescription: 'Real-time notifications for attendance and device events',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
    );
  }
}
