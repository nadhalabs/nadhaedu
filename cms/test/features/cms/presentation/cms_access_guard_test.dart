import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/features/authentication/application/auth_controller.dart';
import 'package:nadha_cms/features/authentication/application/auth_providers.dart';
import 'package:nadha_cms/features/authentication/application/auth_service.dart';
import 'package:nadha_cms/features/authentication/domain/auth_session.dart';
import 'package:nadha_cms/features/authentication/domain/learner_identity.dart';
import 'package:nadha_cms/features/cms/application/cms_providers.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/data/foundation_cms_data_source.dart';
import 'package:nadha_cms/features/cms/presentation/screens/cms_unauthorized_screen.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  group('CMS Route Access Guard Tests', () {
    late AuthController learnerAuthController;

    setUp(() async {
      const learnerIdentity = LearnerIdentity(
        id: 'u-learner',
        email: 'student@example.com',
        displayName: 'Normal Student',
        hasCompletedOnboarding: true,
        role: 'learner',
      );

      final learnerSession = AuthSession(
        identity: learnerIdentity,
        sessionId: 'sess-learner',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );

      final authRepo = FakeAuthRepository(restoredSession: learnerSession);
      learnerAuthController = AuthController(AuthService(authRepo));
      await learnerAuthController.bootstrap();
    });

    testWidgets(
      'Non-staff learner navigating to /admin/unauthorized sees access restricted screen',
      (tester) async {
        final repository = CmsRepositoryImpl(
          remoteDataSource: FoundationCmsDataSource(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                (ref) => learnerAuthController,
              ),
              cmsRepositoryProvider.overrideWithValue(repository),
            ],
            child: const MaterialApp(home: CmsUnauthorizedScreen()),
          ),
        );

        expect(find.text('Access Restricted'), findsOneWidget);
        expect(find.textContaining('student@example.com'), findsOneWidget);
        expect(find.text('Sign In as Admin'), findsOneWidget);
      },
    );
  });
}
