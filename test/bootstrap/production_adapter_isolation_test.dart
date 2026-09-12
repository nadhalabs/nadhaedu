import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_config.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/assessments/application/assessment_providers.dart';
import 'package:learning_platform/features/assessments/data/remote_assessment_data_source.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/authentication/data/backend_auth_data_source.dart';
import 'package:learning_platform/features/certificates/application/certificate_providers.dart';
import 'package:learning_platform/features/certificates/data/remote_certificate_data_source.dart';
import 'package:learning_platform/features/commerce/application/commerce_providers.dart';
import 'package:learning_platform/features/commerce/data/remote_commerce_data_source.dart';
import 'package:learning_platform/features/commerce/data/unconfigured_platform_billing_service.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_providers.dart';
import 'package:learning_platform/features/content_catalog/data/remote_catalog_data_source.dart';
import 'package:learning_platform/features/downloads/application/download_providers.dart';
import 'package:learning_platform/features/downloads/data/remote_download_data_source.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_providers.dart';
import 'package:learning_platform/features/entitlements/data/remote_entitlement_data_source.dart';
import 'package:learning_platform/features/learning_progress/application/learning_providers.dart';
import 'package:learning_platform/features/learning_progress/data/remote_learning_data_source.dart';
import 'package:learning_platform/features/notifications/application/notification_providers.dart';
import 'package:learning_platform/features/notifications/data/local_notification_service.dart';
import 'package:learning_platform/features/notifications/data/push_notification_service.dart';
import 'package:learning_platform/features/notifications/data/remote_notification_data_source.dart';
import 'package:learning_platform/features/profile/application/profile_providers.dart';
import 'package:learning_platform/features/profile/data/remote_profile_data_source.dart';

final class _NoopApiClient implements ApiClient {
  @override
  Future<Result<Map<String, Object?>>> get(
    String path, {
    Map<String, Object?> query = const {},
    bool authenticated = true,
  }) async => const Success({});
  @override
  Future<Result<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async => const Success({});
  @override
  Future<Result<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async => const Success({});
  @override
  Future<Result<Map<String, Object?>>> delete(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async => const Success({});
}

void main() {
  test('staging and production select only backend remote adapters', () {
    for (final environment in [
      AppEnvironment.staging,
      AppEnvironment.production,
    ]) {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(
              environment: environment,
              apiBaseUri: Uri.parse('https://api.example.test'),
              enableDiagnostics: false,
            ),
          ),
          apiClientProvider.overrideWithValue(_NoopApiClient()),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(authRemoteDataSourceProvider),
        isA<BackendAuthDataSource>(),
      );
      expect(
        container.read(catalogDataSourceProvider),
        isA<RemoteCatalogDataSource>(),
      );
      expect(
        container.read(learningDataSourceProvider),
        isA<RemoteLearningDataSource>(),
      );
      expect(
        container.read(entitlementDataSourceProvider),
        isA<RemoteEntitlementDataSource>(),
      );
      expect(
        container.read(assessmentDataSourceProvider),
        isA<RemoteAssessmentDataSource>(),
      );
      expect(
        container.read(certificateDataSourceProvider),
        isA<RemoteCertificateDataSource>(),
      );
      expect(
        container.read(commerceDataSourceProvider),
        isA<RemoteCommerceDataSource>(),
      );
      expect(
        container.read(platformBillingServiceProvider),
        isA<UnconfiguredPlatformBillingService>(),
      );
      expect(
        container.read(downloadDataSourceProvider),
        isA<RemoteDownloadDataSource>(),
      );
      expect(
        container.read(notificationDataSourceProvider),
        isA<RemoteNotificationDataSource>(),
      );
      expect(
        container.read(pushNotificationServiceProvider),
        isA<UnconfiguredPushNotificationService>(),
      );
      expect(
        container.read(localNotificationServiceProvider),
        isA<UnconfiguredLocalNotificationService>(),
      );
      expect(
        container.read(profileDataSourceProvider),
        isA<RemoteProfileDataSource>(),
      );
    }
  });
}
