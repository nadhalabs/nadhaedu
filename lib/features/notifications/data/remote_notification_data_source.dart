import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/notifications/data/notification_data_source.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';
import 'package:learning_platform/features/notifications/domain/notification_preferences.dart';

final class RemoteNotificationDataSource implements NotificationDataSource {
  const RemoteNotificationDataSource(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<NotificationPage> getNotifications({
    String? cursor,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    final query = <String, Object?>{
      'limit': limit,
      'unread_only': unreadOnly,
      'cursor': ?cursor,
    };
    final result = await _apiClient.get('/api/v1/notifications', query: query);
    switch (result) {
      case Success(value: final data):
        final itemsList = (data['items'] as List<dynamic>?) ?? [];
        final items = itemsList
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
        final nextCursor = data['nextCursor'] as String?;

        return NotificationPage(
          items: items,
          unreadCount: unreadCount,
          nextCursor: nextCursor,
        );
      case Failure(failure: final f):
        throw f;
    }
  }

  @override
  Future<NotificationItem> markAsRead(String notificationId) async {
    final result = await _apiClient.post(
      '/api/v1/notifications/$notificationId/read',
    );
    switch (result) {
      case Success(value: final data):
        return NotificationItem.fromJson(
          data['notification'] as Map<String, dynamic>,
        );
      case Failure(failure: final f):
        throw f;
    }
  }

  @override
  Future<int> markAllAsRead() async {
    final result = await _apiClient.post('/api/v1/notifications/read-all');
    switch (result) {
      case Success(value: final data):
        return (data['markedCount'] as num?)?.toInt() ?? 0;
      case Failure(failure: final f):
        throw f;
    }
  }

  @override
  Future<NotificationPreferences> getPreferences() async {
    final result = await _apiClient.get('/api/v1/notifications/preferences');
    switch (result) {
      case Success(value: final data):
        return NotificationPreferences.fromJson(
          data['preferences'] as Map<String, dynamic>,
        );
      case Failure(failure: final f):
        throw f;
    }
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    final result = await _apiClient.put(
      '/api/v1/notifications/preferences',
      body: preferences.toJson(),
    );
    switch (result) {
      case Success(value: final data):
        return NotificationPreferences.fromJson(
          data['preferences'] as Map<String, dynamic>,
        );
      case Failure(failure: final f):
        throw f;
    }
  }

  @override
  Future<void> registerPushToken(
    String token,
    String platform, {
    String? deviceName,
  }) async {
    final result = await _apiClient.post(
      '/api/v1/notifications/push-tokens',
      body: {'token': token, 'platform': platform, 'deviceName': ?deviceName},
    );
    if (result case Failure(failure: final f)) {
      throw f;
    }
  }

  @override
  Future<void> revokePushToken(String token) async {
    final result = await _apiClient.delete(
      '/api/v1/notifications/push-tokens/$token',
    );
    if (result case Failure(failure: final f)) {
      throw f;
    }
  }
}
