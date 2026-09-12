import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_config.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_providers.dart';
import 'package:learning_platform/features/content_catalog/data/catalog_repository_impl.dart';
import 'package:learning_platform/features/content_catalog/data/foundation_catalog_data_source.dart';
import 'package:learning_platform/features/downloads/application/download_providers.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_providers.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_reason.dart';
import 'package:learning_platform/features/learning_progress/application/learning_providers.dart';
import 'package:learning_platform/features/learning_progress/data/foundation_learning_data_source.dart';
import 'package:learning_platform/features/learning_progress/data/learning_repository_impl.dart';
import 'package:learning_platform/features/learning_progress/presentation/learning_screen.dart';

import '../../../helpers/memory_key_value_store.dart';

void main() {
  testWidgets('learner can complete and navigate between lessons', (
    tester,
  ) async {
    final store = MemoryKeyValueStore();
    final catalog = CatalogRepositoryImpl(
      remote: FoundationCatalogDataSource(),
      localStore: store,
    );
    final learning = LearningRepositoryImpl(
      remote: FoundationLearningDataSource(),
      localStore: store,
      learnerId: 'learner-1',
    );

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
          keyValueStoreProvider.overrideWithValue(store),
          catalogRepositoryProvider.overrideWithValue(catalog),
          learningRepositoryProvider.overrideWithValue(learning),
          currentLearnerIdProvider.overrideWithValue('learner-1'),
          accessDecisionProvider.overrideWith(
            (ref, query) => AccessDecision(
              resourceType: query.resourceType,
              resourceId: query.resourceId,
              canAccess: true,
              state: AccessState.free,
              reason: AccessReason.freeContent,
              evaluatedAt: DateTime.utc(2026, 8, 31),
            ),
          ),
        ],
        child: const MaterialApp(
          home: LearningScreen(
            courseId: 'course-1',
            initialLessonId: 'lesson-0-2',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Core concepts'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Mark complete'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Next lesson'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Next lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Reference guide'), findsWidgets);
  });
}
