import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/features/notifications/application/notification_providers.dart';
import 'package:learning_platform/features/settings/application/settings_controller.dart';
import 'package:learning_platform/features/settings/data/settings_repository.dart';
import 'package:learning_platform/features/settings/domain/app_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final store = ref.watch(keyValueStoreProvider);
  return SettingsRepositoryImpl(store);
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
      final repository = ref.watch(settingsRepositoryProvider);
      final analytics = ref.watch(platformAnalyticsProvider);
      return SettingsController(repository, analytics: analytics);
    });
