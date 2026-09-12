import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/notifications/application/notification_preferences_controller.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';
import 'package:learning_platform/features/notifications/domain/notification_preferences.dart';
import 'package:learning_platform/features/notifications/domain/notification_repository.dart';

final class _FakeNotificationRepository implements NotificationRepository {
  NotificationPreferences preferences = const NotificationPreferences();
  bool shouldFail = false;

  @override
  Future<Result<NotificationPage>> getNotifications({
    String? cursor,
    int limit = 20,
    bool unreadOnly = false,
  }) async => const Success(NotificationPage(items: [], unreadCount: 0));

  @override
  Future<Result<NotificationItem>> markAsRead(String notificationId) async =>
      throw UnimplementedError();

  @override
  Future<Result<int>> markAllAsRead() async => const Success(0);

  @override
  Future<Result<NotificationPreferences>> getPreferences() async {
    if (shouldFail) {
      return const Failure(
        NetworkFailure(code: 'network_error', message: 'Failed to fetch'),
      );
    }
    return Success(preferences);
  }

  @override
  Future<Result<NotificationPreferences>> updatePreferences(
    NotificationPreferences updated,
  ) async {
    if (shouldFail) {
      return const Failure(
        NetworkFailure(code: 'network_error', message: 'Failed to update'),
      );
    }
    preferences = updated;
    return Success(preferences);
  }

  @override
  Future<Result<void>> registerPushToken(
    String token,
    String platform, {
    String? deviceName,
  }) async => const Success(null);

  @override
  Future<Result<void>> revokePushToken(String token) async =>
      const Success(null);
}

void main() {
  group('NotificationPreferencesController', () {
    late _FakeNotificationRepository repository;

    setUp(() {
      repository = _FakeNotificationRepository();
    });

    test('loads preferences on init', () async {
      repository.preferences = const NotificationPreferences(
        pushCourseUpdates: false,
        emailMarketing: false,
      );

      final controller = NotificationPreferencesController(repository);
      await controller.loadPreferences();

      expect(controller.state.preferences.pushCourseUpdates, isFalse);
      expect(controller.state.preferences.emailMarketing, isFalse);
      expect(controller.state.isLoading, isFalse);
    });

    test('updates preferences successfully', () async {
      final controller = NotificationPreferencesController(repository);
      await controller.loadPreferences();

      final updated = const NotificationPreferences(
        emailCourseUpdates: false,
        pushLearningReminders: false,
      );
      await controller.updatePreferences(updated);

      expect(controller.state.preferences.emailCourseUpdates, isFalse);
      expect(controller.state.preferences.pushLearningReminders, isFalse);
      expect(controller.state.isSaving, isFalse);
    });

    test('reverts on failure', () async {
      final controller = NotificationPreferencesController(repository);
      await controller.loadPreferences();

      repository.shouldFail = true;
      final updated = const NotificationPreferences(emailCourseUpdates: false);
      await controller.updatePreferences(updated);

      expect(controller.state.failure, isNotNull);
      expect(controller.state.preferences.emailCourseUpdates, isTrue);
    });
  });
}
