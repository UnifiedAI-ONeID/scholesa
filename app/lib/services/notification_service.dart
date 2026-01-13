import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// Notification service for in-app notifications
/// Based on docs/17_MESSAGING_NOTIFICATIONS_SPEC.md
class NotificationService extends ChangeNotifier {
  NotificationService({
    required this.telemetryService,
    this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TelemetryService telemetryService;
  final String? userId;
  final FirebaseFirestore _firestore;

  List<AppNotification> _notifications = <AppNotification>[];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  /// Load notifications for user
  Future<void> loadNotifications() async {
    if (userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _notifications = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return AppNotification(
          id: doc.id,
          title: data['title'] as String? ?? '',
          body: data['body'] as String? ?? '',
          notificationType: data['type'] as String? ?? 'general',
          isRead: data['isRead'] as bool? ?? false,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          deepLink: data['deepLink'] as String?,
          metadata: data['metadata'] as Map<String, dynamic>?,
        );
      }).toList();

      _unreadCount = _notifications.where((AppNotification n) => !n.isRead).length;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('NotificationService.loadNotifications error: $e');
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    if (userId == null) return false;

    try {
      await _firestore.collection('notifications').doc(notificationId).update(<String, dynamic>{
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      await telemetryService.trackNotificationRead(notificationId: notificationId);

      // Update local list
      final int index = _notifications.indexWhere((AppNotification n) => n.id == notificationId);
      if (index >= 0 && !_notifications[index].isRead) {
        _notifications[index] = AppNotification(
          id: _notifications[index].id,
          title: _notifications[index].title,
          body: _notifications[index].body,
          notificationType: _notifications[index].notificationType,
          isRead: true,
          createdAt: _notifications[index].createdAt,
          deepLink: _notifications[index].deepLink,
          metadata: _notifications[index].metadata,
        );
        _unreadCount = _notifications.where((AppNotification n) => !n.isRead).length;
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('NotificationService.markAsRead error: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (userId == null) return;

    try {
      final WriteBatch batch = _firestore.batch();
      
      for (final AppNotification notification in _notifications) {
        if (!notification.isRead) {
          batch.update(
            _firestore.collection('notifications').doc(notification.id),
            <String, dynamic>{
              'isRead': true,
              'readAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      await batch.commit();

      // Update local list
      _notifications = _notifications.map((AppNotification n) => AppNotification(
        id: n.id,
        title: n.title,
        body: n.body,
        notificationType: n.notificationType,
        isRead: true,
        createdAt: n.createdAt,
        deepLink: n.deepLink,
        metadata: n.metadata,
      )).toList();
      
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationService.markAllAsRead error: $e');
    }
  }

  /// Dismiss notification
  Future<bool> dismiss(String notificationId) async {
    if (userId == null) return false;

    try {
      await _firestore.collection('notifications').doc(notificationId).update(<String, dynamic>{
        'dismissed': true,
        'dismissedAt': FieldValue.serverTimestamp(),
      });

      await telemetryService.trackNotificationDismissed(notificationId: notificationId);

      // Remove from local list
      final bool wasUnread = _notifications.any((AppNotification n) => n.id == notificationId && !n.isRead);
      _notifications.removeWhere((AppNotification n) => n.id == notificationId);
      if (wasUnread) {
        _unreadCount = _notifications.where((AppNotification n) => !n.isRead).length;
      }
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('NotificationService.dismiss error: $e');
      return false;
    }
  }
}

/// Model for app notification
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    required this.isRead,
    required this.createdAt,
    this.deepLink,
    this.metadata,
  });

  final String id;
  final String title;
  final String body;
  final String notificationType;
  final bool isRead;
  final DateTime createdAt;
  final String? deepLink;
  final Map<String, dynamic>? metadata;

  String get timeAgo {
    final Duration diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
