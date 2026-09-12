import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/routing/app_destination.dart';
import 'package:learning_platform/features/notifications/application/notification_controller.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';
import 'package:learning_platform/features/notifications/domain/notification_preferences.dart';
import 'package:learning_platform/features/notifications/domain/notification_repository.dart';

final class _FakeNotificationRepository implements NotificationRepository {
  List<NotificationItem> items = [];
  int unreadCount = 0;
  String? nextCursor;
  bool shouldFail = false;

  @override
  Future<Result<NotificationPage>> getNotifications({
    String? cursor,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    if (shouldFail) {
      return const Failure(
        NetworkFailure(code: 'network_error', message: 'Failed to fetch'),
      );
    }
    return Success(
      NotificationPage(
        items: items,
        unreadCount: unreadCount,
        nextCursor: nextCursor,
      ),
    );
  }

  @override
  Future<Result<NotificationItem>> markAsRead(String notificationId) async {
    final item = items.firstWhere((n) => n.id == notificationId);
    return Success(item.copyWith(readAt: DateTime.now()));
  }

  @override
  Future<Result<int>> markAllAsRead() async {
    final count = unreadCount;
    unreadCount = 0;
    return Success(count);
  }

  @override
  Future<Result<NotificationPreferences>> getPreferences() async =>
      const Success(NotificationPreferences());

  @override
  Future<Result<NotificationPreferences>> updatePreferences(
    NotificationPreferences preferences,
  ) async => Success(preferences);

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
  group('NotificationController', () {
    late _FakeNotificationRepository repository;

    setUp(() {
      repository = _FakeNotificationRepository();
    });

    test('loads notifications on initialization', () async {
      repository.items = [
        NotificationItem(
          id: 'notif_1',
          type: NotificationType.courseUpdate,
          title: 'Course Update',
          body: 'Check out new lessons.',
          destination: const AppDestinationCourse('course_1'),
          priority: NotificationPriority.normal,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      repository.unreadCount = 1;

      final controller = NotificationController(repository);
      await controller.loadNotifications();

      expect(controller.state.items.length, 1);
      expect(controller.state.unreadCount, 1);
      expect(controller.state.isLoading, isFalse);
    });

    test('handles failure gracefully', () async {
      repository.shouldFail = true;
      final controller = NotificationController(repository);
      await controller.loadNotifications();

      expect(controller.state.failure, isNotNull);
      expect(controller.state.isLoading, isFalse);
    });

    test('markAsRead optimistically updates state', () async {
      repository.items = [
        NotificationItem(
          id: 'notif_1',
          type: NotificationType.courseUpdate,
          title: 'Course Update',
          body: 'Check out new lessons.',
          destination: const AppDestinationCourse('course_1'),
          priority: NotificationPriority.normal,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      repository.unreadCount = 1;

      final controller = NotificationController(repository);
      await controller.loadNotifications();

      await controller.markAsRead('notif_1');

      expect(controller.state.unreadCount, 0);
      expect(controller.state.items.first.isRead, isTrue);
    });

    test('markAllAsRead sets unread count to 0 and all items read', () async {
      repository.items = [
        NotificationItem(
          id: 'notif_1',
          type: NotificationType.courseUpdate,
          title: 'Course 1',
          body: 'New lesson',
          destination: const AppDestinationCourse('c1'),
          priority: NotificationPriority.normal,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        NotificationItem(
          id: 'notif_2',
          type: NotificationType.lessonReminder,
          title: 'Course 2',
          body: 'Reminder',
          destination: const AppDestinationCourse('c2'),
          priority: NotificationPriority.high,
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      ];
      repository.unreadCount = 2;

      final controller = NotificationController(repository);
      await controller.loadNotifications();

      await controller.markAllAsRead();

      expect(controller.state.unreadCount, 0);
      expect(controller.state.items.every((n) => n.isRead), isTrue);
    });
  });
}
