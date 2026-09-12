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
import 'package:nadha_cms/features/cms/presentation/screens/cms_courses_screen.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  group('CmsCoursesScreen Widget Tests', () {
    late AuthController adminAuthController;

    setUp(() async {
      const adminIdentity = LearnerIdentity(
        id: 'admin-1',
        email: 'admin@nadha.io',
        displayName: 'Lead Admin',
        hasCompletedOnboarding: true,
        role: 'admin',
      );

      final adminSession = AuthSession(
        identity: adminIdentity,
        sessionId: 'sess-1',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );

      final authRepo = FakeAuthRepository(restoredSession: adminSession);
      adminAuthController = AuthController(AuthService(authRepo));
      await adminAuthController.bootstrap();
    });

    testWidgets('renders course catalog table and filter chips', (
      tester,
    ) async {
      final repository = CmsRepositoryImpl(
        remoteDataSource: FoundationCmsDataSource(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => adminAuthController),
            cmsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: CmsCoursesScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Course Catalog & Content'), findsOneWidget);
      expect(find.text('Complete Flutter & Dart Architecture'), findsOneWidget);
      expect(find.text('Server-Driven UI with Flutter'), findsOneWidget);

      // Filter by 'Drafts'
      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();

      expect(find.text('Server-Driven UI with Flutter'), findsOneWidget);
      expect(find.text('Complete Flutter & Dart Architecture'), findsNothing);
    });
  });
}
