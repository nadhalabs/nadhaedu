import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/bootstrap/learning_app.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_config.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/core/security/secure_store.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/authentication/data/foundation_auth_data_source.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_providers.dart';
import 'package:learning_platform/features/content_catalog/data/foundation_catalog_data_source.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_providers.dart';
import 'package:learning_platform/features/entitlements/data/foundation_entitlement_data_source.dart';

import '../../../helpers/memory_key_value_store.dart';

void main() {
  testWidgets('registration flows through onboarding to authenticated home', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(
              environment: AppEnvironment.development,
              apiBaseUri: Uri.parse('http://localhost'),
              enableDiagnostics: false,
            ),
          ),
          secureStoreProvider.overrideWithValue(_MemorySecureStore()),
          authRemoteDataSourceProvider.overrideWithValue(
            FoundationAuthDataSource(),
          ),
          catalogDataSourceProvider.overrideWithValue(
            FoundationCatalogDataSource(),
          ),
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          entitlementDataSourceProvider.overrideWithValue(
            FoundationEntitlementDataSource(),
          ),
        ],
        child: const LearningApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Test Learner',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'learner@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'long-password',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Your next discovery starts here'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CBSE').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Class 10').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Test Learner'), findsOneWidget);
    expect(find.byTooltip('Profile & Account'), findsOneWidget);
  });
}

final class _MemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
