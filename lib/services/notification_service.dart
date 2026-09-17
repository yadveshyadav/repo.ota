import 'dart:collection';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';
import '../widgets/notifications/notification_popup_overlay.dart';

/// Centralized In-App & Push Notification Service for HERO App
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _keyNotificationsJson = 'hero_notifications_json';

  List<AppNotification> _notifications = [];
  bool _isInitialized = false;

  List<AppNotification> get notifications => UnmodifiableListView(_notifications);

  /// Get notifications specifically targeted to the employee [userId]
  List<AppNotification> getNotificationsForUser(String userId) {
    if (userId.isEmpty) return _notifications;
    return _notifications.where((n) => n.recipientId == userId || n.recipientId == 'all').toList();
  }

  /// Get unread notifications count for the employee [userId]
  int getUnreadCountForUser(String userId) {
    return getNotificationsForUser(userId).where((n) => !n.isRead).length;
  }

  /// Initialize persistent storage and load saved notifications
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_keyNotificationsJson);

      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> rawList = jsonDecode(savedJson);
        _notifications = rawList
            .whereType<Map<String, dynamic>>()
            .map((j) => AppNotification.fromJson(j))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationService] Init error: $e');
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Create and deliver notification targeted specifically to the employee [recipientId]
  Future<void> addNotification(
    AppNotification notification, {
    bool showPopup = true,
  }) async {
    await init();
    _notifications.insert(0, notification);
    await _persist();
    notifyListeners();

    if (showPopup) {
      showPopupNotification(notification);
    }
  }

  /// Trigger a pop-up banner notification on top of active screen
  void showPopupNotification(
    AppNotification notification, {
    BuildContext? context,
    VoidCallback? onTap,
  }) {
    NotificationPopupOverlay.show(
      notification: notification,
      context: context,
      onTap: onTap,
    );
  }

  /// Mark notification as read for recipient
  Future<void> markAsRead(String notificationId) async {
    await init();
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _persist();
      notifyListeners();
    }
  }

  /// Clear notifications for testing
  Future<void> clearAll() async {
    _notifications.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_keyNotificationsJson, jsonEncode(jsonList));
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationService] Persist error: $e');
      }
    }
  }
}
