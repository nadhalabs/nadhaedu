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
import 'package:nadha_cms/features/cms/presentation/screens/cms_dashboard_screen.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  group('CmsDashboardScreen Widget Tests', () {
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

    testWidgets('renders all 6 metric cards, warnings, and recent activity', (
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
          child: const MaterialApp(home: CmsDashboardScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Platform Operations Dashboard'), findsOneWidget);
      expect(find.text('TOTAL USERS'), findsOneWidget);
      expect(find.text('ACTIVE LEARNERS'), findsOneWidget);
      expect(find.text('TOTAL COURSES'), findsOneWidget);
      expect(find.text('ENROLLMENTS'), findsOneWidget);
      expect(find.text('COMMERCE VOLUME'), findsOneWidget);
      expect(find.text('CERTIFICATES'), findsOneWidget);

      // Warning banner
      expect(find.text('Operational Environment Notice'), findsOneWidget);

      // Recent activity & transactions tables
      expect(find.text('Recent Privileged Admin Activity'), findsOneWidget);
      expect(find.text('Recent Transactions'), findsOneWidget);
    });
  });
}
