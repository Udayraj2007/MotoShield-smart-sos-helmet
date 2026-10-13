import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize local notification channels and permissions.
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    // Android Initialization Settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Initialization Settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click action if needed
      },
    );

    // Request permissions on Android 13+ & iOS
    if (!kIsWeb && Platform.isAndroid) {
      await Permission.notification.request();
    }

    _initialized = true;
  }

  /// Create High Priority Notification Details
  NotificationDetails _getNotificationDetails({
    required String channelId,
    required String channelName,
    required String channelDescription,
    Importance importance = Importance.max,
    Priority priority = Priority.high,
  }) {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
  }

  /// 1. Show Crash Detected Alert Notification
  Future<void> showCrashNotification({int countdownSeconds = 5}) async {
    await init();
    final details = _getNotificationDetails(
      channelId: 'smart_sos_emergency',
      channelName: 'Emergency SOS Alerts',
      channelDescription: 'High priority crash and emergency distress notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      1001,
      '🚨 ACCIDENT DETECTED!',
      'Impact detected by MotoShield! Emergency countdown started ($countdownSeconds sec).',
      details,
    );
  }

  /// 2. Show SOS Dispatched Alert Notification
  Future<void> showSosDispatchedNotification() async {
    await init();
    final details = _getNotificationDetails(
      channelId: 'smart_sos_emergency',
      channelName: 'Emergency SOS Alerts',
      channelDescription: 'High priority crash and emergency distress notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      1002,
      '🚨 SOS EMERGENCY DISPATCHED!',
      'Automatic Voice Call and Live GPS coordinates dispatched to emergency contacts.',
      details,
    );
  }

  /// 3. Show Helmet Connected Notification
  Future<void> showHelmetConnectedNotification() async {
    await init();
    final details = _getNotificationDetails(
      channelId: 'smart_sos_status',
      channelName: 'Helmet Device Status',
      channelDescription: 'Bluetooth connection and helmet telemetry notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    await _notificationsPlugin.show(
      2001,
      '⛑️ Helmet Connected',
      'MotoShield Bluetooth link established successfully.',
      details,
    );
  }

  /// 4. Show Helmet Disconnected Notification
  Future<void> showHelmetDisconnectedNotification() async {
    await init();
    final details = _getNotificationDetails(
      channelId: 'smart_sos_status',
      channelName: 'Helmet Device Status',
      channelDescription: 'Bluetooth connection and helmet telemetry notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      2002,
      '⚠️ Helmet Disconnected',
      'Bluetooth link with MotoShield lost. Auto-reconnecting...',
      details,
    );
  }

  /// 5. Show Low Battery Warning Notification
  Future<void> showLowBatteryNotification(int percent) async {
    await init();
    final details = _getNotificationDetails(
      channelId: 'smart_sos_status',
      channelName: 'Helmet Device Status',
      channelDescription: 'Bluetooth connection and helmet telemetry notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      3001,
      '🔋 Low Battery Warning',
      'MotoShield battery level is at $percent%. Please charge your helmet.',
      details,
    );
  }

  /// 6. Generic Custom Notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    final details = _getNotificationDetails(
      channelId: 'smart_sos_general',
      channelName: 'General Notifications',
      channelDescription: 'General app notifications and updates',
    );

    await _notificationsPlugin.show(id, title, body, details);
  }
}
