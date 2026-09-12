import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/authentication/application/auth_controller.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/authentication/application/auth_service.dart';
import 'package:learning_platform/features/authentication/domain/auth_session.dart';
import 'package:learning_platform/features/authentication/domain/learner_identity.dart';
import 'package:learning_platform/features/certificates/application/certificate_providers.dart';
import 'package:learning_platform/features/certificates/data/foundation_certificate_data_source.dart';
import 'package:learning_platform/features/certificates/presentation/certificate_detail_screen.dart';
import 'package:learning_platform/features/certificates/presentation/certificate_verification_screen.dart';
import 'package:learning_platform/features/certificates/presentation/certificates_screen.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  group('Certificates UI Presentation Tests', () {
    late FoundationCertificateDataSource dataSource;
    late AuthController authController;

    setUp(() async {
      dataSource = FoundationCertificateDataSource();
      final session = AuthSession(
        sessionId: 'sess-cert-123',
        identity: const LearnerIdentity(
          id: 'dev-learner-id',
          email: 'alex.mercer@example.com',
          displayName: 'Alex Mercer',
          hasCompletedOnboarding: true,
        ),
        expiresAt: DateTime.utc(2027, 1, 1),
      );

      final authRepo = FakeAuthRepository(restoredSession: session);
      authController = AuthController(AuthService(authRepo));
      await authController.bootstrap();
    });

    testWidgets(
      'CertificatesScreen renders list of earned certificates with revoked state badge',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => authController),
              certificateDataSourceProvider.overrideWithValue(dataSource),
            ],
            child: const MaterialApp(home: CertificatesScreen()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('My Certificates'), findsOneWidget);
        expect(find.text('Look what you’ve learned'), findsOneWidget);
        expect(find.text('Modern Application Development'), findsOneWidget);
        expect(find.text('Design Systems in Practice'), findsOneWidget);
        expect(find.text('Revoked'), findsOneWidget);
        expect(find.text('Distinction (92%)'), findsOneWidget);
      },
    );

    testWidgets(
      'CertificateDetailScreen renders official certificate details and verification section',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => authController),
              certificateDataSourceProvider.overrideWithValue(dataSource),
            ],
            child: const MaterialApp(
              home: CertificateDetailScreen(certificateId: 'cert-101'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('CERTIFICATE OF COMPLETION'), findsOneWidget);
        expect(find.text('Alex Mercer'), findsOneWidget);
        expect(find.text('Modern Application Development'), findsOneWidget);
        expect(find.text('Nadha Edu Institute of Technology'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Verify Credential Online'),
          200,
        );
        await tester.pumpAndSettle();

        expect(find.text('Verify Credential Online'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText &&
                (widget.data?.contains('CERT-2026-98124') ?? false),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CertificateDetailScreen displays revocation notice when certificate is revoked',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => authController),
              certificateDataSourceProvider.overrideWithValue(dataSource),
            ],
            child: const MaterialApp(
              home: CertificateDetailScreen(certificateId: 'cert-102'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Certificate Revoked'), findsOneWidget);
        expect(
          find.textContaining('superseded following academic integrity audit'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CertificateVerificationScreen displays verified active credential info',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              certificateDataSourceProvider.overrideWithValue(dataSource),
            ],
            child: const MaterialApp(
              home: CertificateVerificationScreen(
                credentialId: 'CERT-2026-98124',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Valid & Authenticated Credential'), findsOneWidget);
        expect(find.text('Alex Mercer'), findsOneWidget);
        expect(find.text('Active / Verified'), findsOneWidget);
      },
    );

    testWidgets(
      'CertificateVerificationScreen displays revoked alert for revoked credential',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              certificateDataSourceProvider.overrideWithValue(dataSource),
            ],
            child: const MaterialApp(
              home: CertificateVerificationScreen(
                credentialId: 'CERT-2026-REVOKED-01',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Invalid or Revoked Credential'), findsOneWidget);
        expect(find.textContaining('academic integrity audit'), findsOneWidget);
      },
    );
  });
}
