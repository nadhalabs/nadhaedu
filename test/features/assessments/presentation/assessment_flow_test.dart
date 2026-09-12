import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/assessments/application/assessment_providers.dart';
import 'package:learning_platform/features/assessments/data/foundation_assessment_data_source.dart';
import 'package:learning_platform/features/assessments/presentation/assessment_screen.dart';
import 'package:learning_platform/features/authentication/application/auth_controller.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/authentication/application/auth_service.dart';
import 'package:learning_platform/features/authentication/domain/auth_session.dart';
import 'package:learning_platform/features/authentication/domain/learner_identity.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  group('Assessment UI Presentation Flow', () {
    testWidgets(
      'Full quiz flow: Intro -> Answer all types -> Submit -> Result & Explanations',
      (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(1024, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final session = AuthSession(
          sessionId: 'sess-123',
          identity: const LearnerIdentity(
            id: 'test-widget-learner',
            email: 'learner@example.com',
            displayName: 'Test Learner',
            hasCompletedOnboarding: true,
          ),
          expiresAt: DateTime.utc(2027, 1, 1),
        );

        final authRepo = FakeAuthRepository(restoredSession: session);
        final authController = AuthController(AuthService(authRepo));
        await authController.bootstrap();

        final dataSource = FoundationAssessmentDataSource();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => authController),
              assessmentDataSourceProvider.overrideWithValue(dataSource),
            ],
            child: const MaterialApp(
              home: AssessmentScreen(assessmentId: 'quiz-foundations-1'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify Intro Screen
        expect(
          find.text('Foundations & Architecture Knowledge Check'),
          findsWidgets,
        );
        expect(find.text('Questions'), findsOneWidget);
        expect(find.text('Time Limit'), findsOneWidget);
        expect(find.text('Passing Score'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('Start Assessment'), 200);
        await tester.pumpAndSettle();
        expect(find.text('Start Assessment'), findsOneWidget);

        // 2. Tap Start Assessment
        await tester.tap(find.text('Start Assessment'));
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        // 3. Question 1: Single Choice
        expect(find.text('Question 1 of 4'), findsOneWidget);
        expect(find.textContaining('pure business rules'), findsOneWidget);
        await tester.tap(find.text('Domain Layer'));
        await tester.pumpAndSettle();

        // Tap Next
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // 4. Question 2: Multiple Choice
        expect(find.text('Question 2 of 4'), findsOneWidget);
        await tester.tap(
          find.text(
            'Answer keys are never transmitted to the client application',
          ),
        );
        await tester.tap(
          find.text(
            'Submissions include idempotency tokens to prevent duplicate scoring',
          ),
        );
        await tester.tap(
          find.text(
            'Attempt limits and duration limits are enforced server-side',
          ),
        );
        await tester.pumpAndSettle();

        // Tap Next
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // 5. Question 3: True/False
        expect(find.text('Question 3 of 4'), findsOneWidget);
        await tester.tap(find.text('False'));
        await tester.pumpAndSettle();

        // Tap Next
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // 6. Question 4: Text Response
        expect(find.text('Question 4 of 4'), findsOneWidget);
        await tester.enterText(
          find.byType(TextField),
          'Centralized access evaluation maintains security policy.',
        );
        await tester.pumpAndSettle();

        // Tap Submit
        expect(find.text('Submit'), findsOneWidget);
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        // Confirmation dialog
        expect(find.text('Submit Assessment?'), findsOneWidget);
        expect(
          find.text('You have answered 4 of 4 questions.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Submit Now'));
        await tester.pumpAndSettle();

        // 7. Verify Results View
        expect(find.text('Assessment Passed!'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('Question Review & Explanations'), findsOneWidget);
        expect(
          find.textContaining('The domain layer defines pure business models'),
          findsOneWidget,
        );
        semantics.dispose();
      },
    );
  });
}
