import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/bootstrap/learning_app.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_config.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/config/branding_config.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/memory_key_value_store.dart';

void main() {
  testWidgets('reads user-facing name from branding configuration', (
    tester,
  ) async {
    const branding = BrandingConfig(displayName: 'Test Learning Product');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(AppEnvironment.development),
          ),
          brandingConfigProvider.overrideWithValue(branding),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
        child: const LearningApp(),
      ),
    );
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, branding.displayName);
  });
}
