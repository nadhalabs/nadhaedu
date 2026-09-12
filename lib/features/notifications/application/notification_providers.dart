import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/core/analytics/platform_analytics.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/notifications/application/notification_controller.dart';
import 'package:learning_platform/features/notifications/application/notification_preferences_controller.dart';
import 'package:learning_platform/features/notifications/application/notification_state.dart';
import 'package:learning_platform/features/notifications/data/foundation_notification_data_source.dart';
import 'package:learning_platform/features/notifications/data/local_notification_service.dart';
import 'package:learning_platform/features/notifications/data/notification_cache_store.dart';
import 'package:learning_platform/features/notifications/data/notification_data_source.dart';
import 'package:learning_platform/features/notifications/data/notification_repository_impl.dart';
import 'package:learning_platform/features/notifications/data/push_notification_service.dart';
import 'package:learning_platform/features/notifications/data/remote_notification_data_source.dart';
import 'package:learning_platform/features/notifications/domain/notification_repository.dart';

final notificationDataSourceProvider = Provider<NotificationDataSource>((ref) {
  return switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => FoundationNotificationDataSource(),
    AppEnvironment.staging || AppEnvironment.production =>
      RemoteNotificationDataSource(ref.watch(apiClientProvider)),
  };
});

final notificationCacheStoreProvider = Provider<NotificationCacheStore?>((ref) {
  final learnerId = ref.watch(authControllerProvider).session?.identity.id;
  if (learnerId == null) return null;
  final store = ref.watch(keyValueStoreProvider);
  return NotificationCacheStore(store, learnerId: learnerId);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dataSource = ref.watch(notificationDataSourceProvider);
  final cacheStore = ref.watch(notificationCacheStoreProvider);
  return NotificationRepositoryImpl(
    dataSource: dataSource,
    cacheStore: cacheStore,
  );
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => MockPushNotificationService(),
    AppEnvironment.staging ||
    AppEnvironment.production => const UnconfiguredPushNotificationService(),
  };
});

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return switch (ref.watch(appConfigProvider).environment) {
    AppEnvironment.development => MockLocalNotificationService(),
    AppEnvironment.staging ||
    AppEnvironment.production => const UnconfiguredLocalNotificationService(),
  };
});

final platformAnalyticsProvider = Provider<PlatformAnalytics>((ref) {
  final service = ref.watch(analyticsProvider);
  return PlatformAnalytics(service);
});

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationState>((ref) {
      final repository = ref.watch(notificationRepositoryProvider);
      final analytics = ref.watch(platformAnalyticsProvider);
      return NotificationController(repository, analytics: analytics);
    });

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationControllerProvider).unreadCount;
});

final notificationPreferencesControllerProvider =
    StateNotifierProvider<
      NotificationPreferencesController,
      NotificationPreferencesState
    >((ref) {
      final repository = ref.watch(notificationRepositoryProvider);
      return NotificationPreferencesController(repository);
    });
