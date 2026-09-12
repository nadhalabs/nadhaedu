import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/features/authentication/application/auth_controller.dart';
import 'package:nadha_cms/features/authentication/application/auth_providers.dart';
import 'package:nadha_cms/features/authentication/application/auth_service.dart';
import 'package:nadha_cms/features/authentication/domain/auth_session.dart';
import 'package:nadha_cms/features/authentication/domain/learner_identity.dart';
import 'package:nadha_cms/features/cms/academic.dart';
import 'package:nadha_cms/features/cms/application/cms_providers.dart';
import 'package:nadha_cms/features/cms/data/cms_repository.dart';
import 'package:nadha_cms/features/cms/data/foundation_cms_data_source.dart';
import 'package:nadha_cms/features/cms/presentation/screens/cms_course_editor_screen.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  group('CmsCourseEditorScreen Widget Tests', () {
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

    testWidgets('renders course editor header, tabs and metadata inputs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = CmsRepositoryImpl(
        remoteDataSource: FoundationCmsDataSource(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            academicRecordsProvider.overrideWith((ref, kind) async => []),
            authControllerProvider.overrideWith((ref) => adminAuthController),
            cmsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: CmsCourseEditorScreen(courseId: 'course-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Edit: Complete Flutter & Dart Architecture'),
        findsOneWidget,
      );
      expect(find.text('General Metadata'), findsOneWidget);
      expect(find.textContaining('Curriculum ('), findsOneWidget);
      expect(find.textContaining('Assessments'), findsOneWidget);
      expect(find.text('Validation & Publishing'), findsOneWidget);

      // Verify metadata fields populated
      expect(find.text('Complete Flutter & Dart Architecture'), findsWidgets);
      expect(find.text('Save Details'), findsOneWidget);

      // Switch to Curriculum Tab
      await tester.tap(find.textContaining('Curriculum ('));
      await tester.pumpAndSettle();

      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('Foundations of Clean Architecture'), findsOneWidget);

      // Switch to Validation & Publishing Tab
      await tester.tap(find.text('Validation & Publishing'));
      await tester.pumpAndSettle();

      expect(
        find.text('Course is Complete & Ready for Publishing'),
        findsOneWidget,
      );
      expect(
        find.text('Authoritative Server Validation Report'),
        findsOneWidget,
      );
    });
  });
}
