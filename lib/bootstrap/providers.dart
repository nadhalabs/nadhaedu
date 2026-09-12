import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:learning_platform/config/app_config.dart';
import 'package:learning_platform/config/branding_config.dart';
import 'package:learning_platform/core/analytics/analytics_service.dart';
import 'package:learning_platform/core/connectivity/network_monitor.dart';
import 'package:learning_platform/core/crash_reporting/crash_reporter.dart';
import 'package:learning_platform/core/logging/app_logger.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/core/persistence/key_value_store.dart';
import 'package:learning_platform/core/security/secure_store.dart';
import 'package:learning_platform/features/authentication/data/auth_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('AppConfig must be overridden during bootstrap.'),
);
final brandingConfigProvider = Provider<BrandingConfig>(
  (ref) => BrandingConfig.temporary,
);
final loggerProvider = Provider<AppLogger>(
  (ref) => DeveloperAppLogger(
    enabled: ref.watch(appConfigProvider).enableDiagnostics,
  ),
);
final analyticsProvider = Provider<AnalyticsService>(
  (ref) => const NoopAnalyticsService(),
);
final crashReporterProvider = Provider<CrashReporter>(
  (ref) => const NoopCrashReporter(),
);
final sessionExpirationProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = DioApiClient(
    baseUri: ref.watch(appConfigProvider).apiBaseUri,
    sessionStore: ref.watch(authSessionStoreProvider),
    onSessionExpired: () =>
        ref.read(sessionExpirationProvider.notifier).state++,
  );
  ref.onDispose(client.close);
  return client;
});
final secureStoreProvider = Provider<SecureStore>(
  (ref) => PlatformSecureStore(const FlutterSecureStorage()),
);
final authSessionStoreProvider = Provider<AuthSessionStore>(
  (ref) => SecureAuthSessionStore(ref.watch(secureStoreProvider)),
);
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) =>
      throw StateError('KeyValueStore must be initialized during bootstrap.'),
);
final networkMonitorProvider = Provider<NetworkMonitor>(
  (ref) => ConnectivityNetworkMonitor(Connectivity()),
);

List<Override> bootstrapOverrides({
  required AppConfig config,
  required SharedPreferences preferences,
}) => [
  appConfigProvider.overrideWithValue(config),
  keyValueStoreProvider.overrideWithValue(SharedPreferencesStore(preferences)),
];
