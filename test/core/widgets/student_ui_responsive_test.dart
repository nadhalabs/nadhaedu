import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/bootstrap/learning_app.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_config.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_theme.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/core/widgets/learning_feedback.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/authentication/domain/auth_session.dart';
import 'package:learning_platform/features/authentication/domain/learner_identity.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/memory_key_value_store.dart';

void main() {
  for (final (width, scale) in [
    (320.0, 1.0),
    (800.0, 1.0),
    (1440.0, 1.0),
    (390.0, 2.0),
  ]) {
    testWidgets('student routes fit width $width and text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(AppEnvironment.development),
          ),
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              restoredSession: AuthSession(
                sessionId: 'ui-test',
                identity: const LearnerIdentity(
                  id: 'dev-learner-id',
                  email: 'learner@example.com',
                  displayName: 'Alex',
                  hasCompletedOnboarding: true,
                ),
                expiresAt: DateTime.now().add(const Duration(days: 1)),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LearningApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Home at $width / $scale');
      final router = container.read(appRouterProvider);
      for (final route in [
        AppRoutes.discover,
        AppRoutes.search,
        AppRoutes.profile,
        AppRoutes.course('course-1'),
        AppRoutes.learn('course-1', lessonId: 'lesson-0-2'),
        AppRoutes.downloads,
        AppRoutes.certificates,
        AppRoutes.certificate('cert-101'),
        AppRoutes.assessment('quiz-foundations-1'),
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$route at $width / $scale',
        );
        // Check the full scrollable surface, including bottom controls.
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          await tester.drag(scrollables.first, const Offset(0, -700));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Scrolled $route at $width / $scale',
          );
        }
      }
      await tester.scrollUntilVisible(find.text('Start Assessment'), 200);
      await tester.tap(find.text('Start Assessment'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Question screen at $width / $scale',
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Multiple choices at $width / $scale',
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'True/false at $width / $scale',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
  }

  testWidgets(
    'feedback fits short screens with large text and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(body: ErrorView(onAction: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    LearningLift(
                      child: SizedBox(height: 48, child: Text('Card')),
                    ),
                    LearningProgress(value: 0.6),
                    LearningCelebration(
                      title: 'Course completed',
                      message: 'Your progress is saved.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
      final feedbackContext = tester.element(find.byType(LearningProgress));
      expect(
        AppMotion.duration(feedbackContext, AppMotion.standard),
        Duration.zero,
      );
    },
  );
}
