import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';
import 'package:learning_platform/features/notifications/domain/notification_preferences.dart';

abstract interface class NotificationRepository {
  Future<Result<NotificationPage>> getNotifications({
    String? cursor,
    int limit = 20,
    bool unreadOnly = false,
  });

  Future<Result<NotificationItem>> markAsRead(String notificationId);

  Future<Result<int>> markAllAsRead();

  Future<Result<NotificationPreferences>> getPreferences();

  Future<Result<NotificationPreferences>> updatePreferences(
    NotificationPreferences preferences,
  );

  Future<Result<void>> registerPushToken(
    String token,
    String platform, {
    String? deviceName,
  });

  Future<Result<void>> revokePushToken(String token);
}
