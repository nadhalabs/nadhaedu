import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/routing/app_destination.dart';
import 'package:learning_platform/features/notifications/application/notification_providers.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';
import 'package:learning_platform/features/notifications/domain/notification_preferences.dart';
import 'package:learning_platform/features/notifications/domain/notification_repository.dart';
import 'package:learning_platform/features/notifications/presentation/notifications_screen.dart';

final class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository({required this.items, this.unreadCount = 0});
  final List<NotificationItem> items;
  int unreadCount;

  @override
  Future<Result<NotificationPage>> getNotifications({
    String? cursor,
    int limit = 20,
    bool unreadOnly = false,
  }) async => Success(NotificationPage(items: items, unreadCount: unreadCount));

  @override
  Future<Result<NotificationItem>> markAsRead(String notificationId) async {
    final item = items.firstWhere((n) => n.id == notificationId);
    return Success(item.copyWith(readAt: DateTime.now()));
  }

  @override
  Future<Result<int>> markAllAsRead() async {
    unreadCount = 0;
    return const Success(0);
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
  testWidgets('NotificationsScreen displays empty state when no items', (
    tester,
  ) async {
    final repo = _FakeNotificationRepository(items: []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('No notifications'), findsOneWidget);
  });

  testWidgets(
    'NotificationsScreen displays notification items and handles mark all as read',
    (tester) async {
      final notif = NotificationItem(
        id: 'notif_1',
        type: NotificationType.courseUpdate,
        title: 'New Flutter Course Added',
        body: 'Explore advanced state management.',
        destination: const AppDestinationCourse('flutter-state'),
        priority: NotificationPriority.normal,
        createdAt: DateTime.now(),
      );
      final repo = _FakeNotificationRepository(items: [notif], unreadCount: 1);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Flutter Course Added'), findsOneWidget);
      expect(find.text('Explore advanced state management.'), findsOneWidget);
      expect(find.text('Mark all as read'), findsOneWidget);

      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();

      expect(find.text('Mark all as read'), findsNothing);
    },
  );
}
