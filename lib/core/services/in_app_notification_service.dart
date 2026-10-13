import 'package:flutter/material.dart';
import '../../features/notifications/screens/notifications_screen.dart';

class InAppNotificationService {
  InAppNotificationService._();
  static final InAppNotificationService instance = InAppNotificationService._();

  final ValueNotifier<List<NotificationItemModel>> notificationsNotifier =
      ValueNotifier<List<NotificationItemModel>>([]);

  final ValueNotifier<bool> hasUnreadNotifier = ValueNotifier<bool>(false);

  void addNotification({
    required String title,
    required String message,
    required IconData icon,
    required Color accentColor,
    bool isAlert = false,
  }) {
    final item = NotificationItemModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
      icon: icon,
      accentColor: accentColor,
      isAlert: isAlert,
      isRead: false,
    );

    final current = List<NotificationItemModel>.from(notificationsNotifier.value);
    current.insert(0, item);
    notificationsNotifier.value = current;
    _updateUnreadStatus();
  }

  void markAllAsRead() {
    for (var n in notificationsNotifier.value) {
      n.isRead = true;
    }
    notificationsNotifier.value = List<NotificationItemModel>.from(notificationsNotifier.value);
    _updateUnreadStatus();
  }

  void markAsRead(String id) {
    for (var n in notificationsNotifier.value) {
      if (n.id == id) {
        n.isRead = true;
      }
    }
    notificationsNotifier.value = List<NotificationItemModel>.from(notificationsNotifier.value);
    _updateUnreadStatus();
  }

  void clearAll() {
    notificationsNotifier.value = [];
    _updateUnreadStatus();
  }

  void _updateUnreadStatus() {
    hasUnreadNotifier.value =
        notificationsNotifier.value.any((n) => !n.isRead);
  }
}
