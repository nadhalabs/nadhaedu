import 'package:flutter/foundation.dart';
import 'package:learning_platform/core/routing/app_destination.dart';

abstract interface class LocalNotificationService {
  Future<void> showNotification({
    required String id,
    required String title,
    required String body,
    AppDestination? destination,
  });

  Future<void> scheduleLearningReminder({
    required String reminderId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  });

  Future<void> cancelReminder(String reminderId);
  Future<void> cancelAll();
}

final class UnconfiguredLocalNotificationService
    implements LocalNotificationService {
  const UnconfiguredLocalNotificationService();

  StateError get _error => StateError(
    'Native local-notification integration is not configured for this build.',
  );

  @override
  Future<void> cancelAll() async => throw _error;
  @override
  Future<void> cancelReminder(String reminderId) async => throw _error;
  @override
  Future<void> scheduleLearningReminder({
    required String reminderId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async => throw _error;
  @override
  Future<void> showNotification({
    required String id,
    required String title,
    required String body,
    AppDestination? destination,
  }) async => throw _error;
}

final class MockLocalNotificationService implements LocalNotificationService {
  final List<Map<String, dynamic>> displayed = [];
  final List<Map<String, dynamic>> scheduled = [];

  @override
  Future<void> showNotification({
    required String id,
    required String title,
    required String body,
    AppDestination? destination,
  }) async {
    displayed.add({
      'id': id,
      'title': title,
      'body': body,
      'destination': destination?.toLocation(),
      'shownAt': DateTime.now(),
    });
    debugPrint('[LocalNotification] Show: $title - $body');
  }

  @override
  Future<void> scheduleLearningReminder({
    required String reminderId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    scheduled.add({
      'id': reminderId,
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime,
    });
    debugPrint('[LocalNotification] Scheduled ($scheduledTime): $title');
  }

  @override
  Future<void> cancelReminder(String reminderId) async {
    scheduled.removeWhere((item) => item['id'] == reminderId);
  }

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
  }
}
