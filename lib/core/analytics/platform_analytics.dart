import 'package:learning_platform/core/analytics/analytics_service.dart';

final class PlatformAnalytics {
  PlatformAnalytics(this._analytics);
  final AnalyticsService _analytics;

  Future<void> notificationReceived({
    required String notificationId,
    required String type,
    required String priority,
  }) {
    return _analytics.track(
      'notification_received',
      properties: {
        'notification_id': notificationId,
        'type': type,
        'priority': priority,
      },
    );
  }

  Future<void> notificationOpened({
    required String notificationId,
    required String type,
    required String destinationType,
  }) {
    return _analytics.track(
      'notification_opened',
      properties: {
        'notification_id': notificationId,
        'type': type,
        'destination_type': destinationType,
      },
    );
  }

  Future<void> notificationMarkedRead({
    required String notificationId,
    required bool isBulk,
  }) {
    return _analytics.track(
      'notification_marked_read',
      properties: {'notification_id': notificationId, 'is_bulk': isBulk},
    );
  }

  Future<void> deepLinkOpened({
    required String destinationType,
    required bool isAuthenticated,
  }) {
    return _analytics.track(
      'deep_link_opened',
      properties: {
        'destination_type': destinationType,
        'is_authenticated': isAuthenticated,
      },
    );
  }

  Future<void> deepLinkFailed({
    required String rawPath,
    required String reason,
  }) {
    return _analytics.track(
      'deep_link_failed',
      properties: {'raw_path': rawPath, 'reason': reason},
    );
  }

  Future<void> profileUpdated({
    required bool hasDisplayName,
    required bool hasPhone,
    required int interestsCount,
    required String language,
  }) {
    return _analytics.track(
      'profile_updated',
      properties: {
        'has_display_name': hasDisplayName,
        'has_phone': hasPhone,
        'interests_count': interestsCount,
        'language': language,
      },
    );
  }

  Future<void> themeChanged({required String themeMode}) {
    return _analytics.track(
      'theme_changed',
      properties: {'theme_mode': themeMode},
    );
  }

  Future<void> settingsChanged({required String settingKey}) {
    return _analytics.track(
      'settings_changed',
      properties: {'setting_key': settingKey},
    );
  }

  Future<void> sessionRevoked({
    required String sessionId,
    required bool isCurrent,
    required bool isAllOthers,
  }) {
    return _analytics.track(
      'session_revoked',
      properties: {
        'session_id': sessionId,
        'is_current': isCurrent,
        'is_all_others': isAllOthers,
      },
    );
  }

  Future<void> accountDeletionStarted() {
    return _analytics.track('account_deletion_started');
  }
}
