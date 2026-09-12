import 'package:learning_platform/features/notifications/domain/notification_item.dart';
import 'package:learning_platform/features/notifications/domain/notification_preferences.dart';

abstract interface class NotificationDataSource {
  Future<NotificationPage> getNotifications({
    String? cursor,
    int limit = 20,
    bool unreadOnly = false,
  });

  Future<NotificationItem> markAsRead(String notificationId);

  Future<int> markAllAsRead();

  Future<NotificationPreferences> getPreferences();

  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  );

  Future<void> registerPushToken(
    String token,
    String platform, {
    String? deviceName,
  });

  Future<void> revokePushToken(String token);
}
