import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/features/authentication/application/auth_controller.dart';
import 'package:nadha_cms/features/authentication/application/auth_providers.dart';
import 'package:nadha_cms/features/authentication/application/auth_service.dart';
import 'package:nadha_cms/features/authentication/domain/auth_session.dart';
import 'package:nadha_cms/features/authentication/domain/learner_identity.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_sidebar.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  group('CmsShell & Navigation Widgets Tests', () {
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

    testWidgets(
      'CmsSidebar renders all navigation options and admin identity',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => adminAuthController),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CmsSidebar(
                  currentRoute: '/admin/dashboard',
                  isCompact: false,
                ),
              ),
            ),
          ),
        );

        expect(find.text('NADHA EDU'), findsOneWidget);
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Courses & Content'), findsOneWidget);
        expect(find.text('Learner Operations'), findsOneWidget);
        expect(find.text('Commerce'), findsOneWidget);
        expect(find.text('Entitlements'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Audit Trail'), findsOneWidget);
        expect(find.text('System & Health'), findsOneWidget);
        expect(find.text('Lead Admin'), findsOneWidget);
        expect(find.text('Admin'), findsOneWidget);
      },
    );

    testWidgets('CmsSidebar renders in compact mode for tablet layouts', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => adminAuthController),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CmsSidebar(
                currentRoute: '/admin/dashboard',
                isCompact: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CmsSidebar), findsOneWidget);
      // Compact mode hides long text labels in sidebar body
      expect(find.text('NADHA EDU'), findsNothing);
      expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
    });

    testWidgets('CmsHeader renders dynamic breadcrumbs and title', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => adminAuthController),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CmsHeader(
                currentRoute: '/admin/courses',
                title: 'Course Catalog & Content',
                subtitle: 'Manage curriculum',
              ),
            ),
          ),
        ),
      );

      expect(find.text('CMS'), findsOneWidget);
      expect(find.text('Courses & Content'), findsWidgets);
      expect(find.text('Course Catalog & Content'), findsOneWidget);
      expect(find.text('Manage curriculum'), findsOneWidget);
      expect(find.text('Systems Ready'), findsOneWidget);
    });
  });
}
