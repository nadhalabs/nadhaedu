import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/notifications/data/notification_cache_store.dart';
import 'package:learning_platform/features/notifications/data/notification_data_source.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';
import 'package:learning_platform/features/notifications/domain/notification_preferences.dart';
import 'package:learning_platform/features/notifications/domain/notification_repository.dart';

final class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required NotificationDataSource dataSource,
    NotificationCacheStore? cacheStore,
  }) : _dataSource = dataSource,
       _cacheStore = cacheStore;

  final NotificationDataSource _dataSource;
  final NotificationCacheStore? _cacheStore;

  @override
  Future<Result<NotificationPage>> getNotifications({
    String? cursor,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final page = await _dataSource.getNotifications(
        cursor: cursor,
        limit: limit,
        unreadOnly: unreadOnly,
      );
      if (cursor == null && _cacheStore != null) {
        await _cacheStore.saveCachedNotifications(page.items);
      }
      return Success(page);
    } on Object catch (error) {
      if (cursor == null && _cacheStore != null) {
        final cached = await _cacheStore.loadCachedNotifications();
        if (cached.isNotEmpty) {
          final unreadCount = cached.where((n) => !n.isRead).length;
          return Success(
            NotificationPage(items: cached, unreadCount: unreadCount),
          );
        }
      }
      if (error is AppFailure) {
        return Failure(error);
      }
      return Failure(
        NetworkFailure(
          code: 'NOTIFICATIONS_FETCH_FAILED',
          message: 'Failed to load notifications: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<NotificationItem>> markAsRead(String notificationId) async {
    try {
      final item = await _dataSource.markAsRead(notificationId);
      return Success(item);
    } on Object catch (error) {
      if (error is AppFailure) {
        return Failure(error);
      }
      return Failure(
        NetworkFailure(
          code: 'NOTIFICATION_MARK_READ_FAILED',
          message: 'Failed to mark notification as read: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<int>> markAllAsRead() async {
    try {
      final count = await _dataSource.markAllAsRead();
      return Success(count);
    } on Object catch (error) {
      if (error is AppFailure) {
        return Failure(error);
      }
      return Failure(
        NetworkFailure(
          code: 'NOTIFICATIONS_MARK_ALL_READ_FAILED',
          message: 'Failed to mark all notifications as read: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<NotificationPreferences>> getPreferences() async {
    try {
      final prefs = await _dataSource.getPreferences();
      return Success(prefs);
    } on Object catch (error) {
      if (error is AppFailure) {
        return Failure(error);
      }
      return Failure(
        NetworkFailure(
          code: 'NOTIFICATION_PREFERENCES_FETCH_FAILED',
          message: 'Failed to load notification preferences: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<NotificationPreferences>> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    try {
      final updated = await _dataSource.updatePreferences(preferences);
      return Success(updated);
    } on Object catch (error) {
      if (error is AppFailure) {
        return Failure(error);
      }
      return Failure(
        NetworkFailure(
          code: 'NOTIFICATION_PREFERENCES_UPDATE_FAILED',
          message: 'Failed to update notification preferences: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> registerPushToken(
    String token,
    String platform, {
    String? deviceName,
  }) async {
    try {
      await _dataSource.registerPushToken(
        token,
        platform,
        deviceName: deviceName,
      );
      return const Success(null);
    } on Object catch (error) {
      if (error is AppFailure) {
        return Failure(error);
      }
      return Failure(
        NetworkFailure(
          code: 'PUSH_TOKEN_REGISTRATION_FAILED',
          message: 'Failed to register push token: $error',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> revokePushToken(String token) async {
    try {
      await _dataSource.revokePushToken(token);
      return const Success(null);
    } on Object catch (error) {
      if (error is AppFailure) {
        return Failure(error);
      }
      return Failure(
        NetworkFailure(
          code: 'PUSH_TOKEN_REVOCATION_FAILED',
          message: 'Failed to revoke push token: $error',
          cause: error,
        ),
      );
    }
  }
}
