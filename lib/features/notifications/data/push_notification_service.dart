import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_platform/features/notifications/domain/notification_item.dart';
import 'package:learning_platform/features/notifications/domain/notification_repository.dart';

enum NotificationPermissionState { notDetermined, granted, denied, provisional }

abstract interface class PushNotificationService {
  Future<NotificationPermissionState> getPermissionState();
  Future<NotificationPermissionState> requestPermission();
  Future<String?> getPushToken();
  Stream<NotificationItem> get onForegroundNotification;
  Stream<NotificationItem> get onNotificationTap;
  Future<void> syncTokenWithBackend(NotificationRepository repository);
  Future<void> revokeToken(NotificationRepository repository);
}

final class UnconfiguredPushNotificationService
    implements PushNotificationService {
  const UnconfiguredPushNotificationService();

  StateError get _error =>
      StateError('FCM/APNs push integration is not configured for this build.');

  @override
  Future<NotificationPermissionState> getPermissionState() async =>
      throw _error;
  @override
  Future<String?> getPushToken() async => throw _error;
  @override
  Stream<NotificationItem> get onForegroundNotification => const Stream.empty();
  @override
  Stream<NotificationItem> get onNotificationTap => const Stream.empty();
  @override
  Future<NotificationPermissionState> requestPermission() async => throw _error;
  @override
  Future<void> revokeToken(NotificationRepository repository) async =>
      throw _error;
  @override
  Future<void> syncTokenWithBackend(NotificationRepository repository) async =>
      throw _error;
}

final class MockPushNotificationService implements PushNotificationService {
  MockPushNotificationService({
    this.initialState = NotificationPermissionState.granted,
    this.initialToken = 'mock_push_token_device_abc',
  });

  NotificationPermissionState initialState;
  String? initialToken;

  final _foregroundController = StreamController<NotificationItem>.broadcast();
  final _tapController = StreamController<NotificationItem>.broadcast();

  @override
  Future<NotificationPermissionState> getPermissionState() async =>
      initialState;

  @override
  Future<NotificationPermissionState> requestPermission() async {
    initialState = NotificationPermissionState.granted;
    return initialState;
  }

  @override
  Future<String?> getPushToken() async => initialToken;

  @override
  Stream<NotificationItem> get onForegroundNotification =>
      _foregroundController.stream;

  @override
  Stream<NotificationItem> get onNotificationTap => _tapController.stream;

  @override
  Future<void> syncTokenWithBackend(NotificationRepository repository) async {
    final token = await getPushToken();
    if (token != null) {
      final platform = defaultTargetPlatform.name;
      await repository.registerPushToken(token, platform);
    }
  }

  @override
  Future<void> revokeToken(NotificationRepository repository) async {
    final token = await getPushToken();
    if (token != null) {
      await repository.revokePushToken(token);
    }
  }

  void simulateForegroundNotification(NotificationItem item) {
    _foregroundController.add(item);
  }

  void simulateNotificationTap(NotificationItem item) {
    _tapController.add(item);
  }

  void dispose() {
    unawaited(_foregroundController.close());
    unawaited(_tapController.close());
  }
}
