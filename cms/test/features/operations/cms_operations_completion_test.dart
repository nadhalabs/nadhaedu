import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/core/networking/api_client.dart';
import 'package:nadha_cms/features/authentication/application/auth_controller.dart';
import 'package:nadha_cms/features/authentication/application/auth_providers.dart';
import 'package:nadha_cms/features/authentication/application/auth_service.dart';
import 'package:nadha_cms/features/authentication/domain/auth_session.dart';
import 'package:nadha_cms/features/authentication/domain/learner_identity.dart';
import 'package:nadha_cms/features/cms/presentation/screens/cms_audit_logs_screen.dart';
import 'package:nadha_cms/features/operations/application/cms_operations_providers.dart';
import 'package:nadha_cms/features/operations/data/cms_operations_repository.dart';
import 'package:nadha_cms/features/operations/presentation/cms_admins_screen.dart';
import 'package:nadha_cms/features/operations/presentation/cms_commerce_screen.dart';
import 'package:nadha_cms/features/operations/presentation/cms_entitlements_screen.dart';
import 'package:nadha_cms/features/operations/presentation/cms_learners_screen.dart';
import 'package:nadha_cms/features/operations/presentation/cms_notifications_screen.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  late _Api api;
  late AuthController auth;

  setUp(() async {
    api = _Api();
    final session = AuthSession(
      identity: const LearnerIdentity(
        id: 'super-1',
        email: 'super@example.com',
        displayName: 'Super Admin',
        hasCompletedOnboarding: true,
        role: 'super_admin',
      ),
      sessionId: 's1',
      expiresAt: DateTime(2100),
    );
    auth = AuthController(
      AuthService(FakeAuthRepository(restoredSession: session)),
    );
    await auth.bootstrap();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => auth),
          cmsOperationsRepositoryProvider.overrideWithValue(
            CmsOperationsRepository(api),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'learner search, filters, reset, and cursor pagination drive API',
    (tester) async {
      api.responses['/api/v1/admin/learners'] = {
        'items': [
          {'id': 'learner-1', 'email': 'one@example.com', 'status': 'active'},
        ],
        'nextCursor': 'learner-1',
      };
      await pump(tester, const CmsLearnersScreen());
      await tester.enterText(
        find.widgetWithText(TextField, 'Name, email, or learner ID'),
        'one@example.com',
      );
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(api.lastQuery['search'], 'one@example.com');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(api.lastQuery['cursor'], 'learner-1');
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(api.lastQuery.containsKey('search'), isFalse);
      expect(find.text('View learner'), findsOneWidget);
    },
  );

  testWidgets(
    'entitlement UI distinguishes provider state and requires reason',
    (tester) async {
      api.responses['/api/v1/admin/entitlements'] = {
        'items': [
          {
            'id': 'e1',
            'learnerId': 'l1',
            'resourceId': 'c1',
            'source': 'admin_grant',
            'status': 'active',
            'version': 1,
          },
          {
            'id': 'e2',
            'learnerId': 'l1',
            'resourceId': 'c2',
            'source': 'purchase',
            'status': 'active',
            'version': 1,
          },
        ],
      };
      await pump(tester, const CmsEntitlementsScreen());
      expect(find.text('Extend'), findsOneWidget);
      expect(find.text('Revoke'), findsOneWidget);
      expect(find.text('Provider owned'), findsOneWidget);
      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke entitlement'));
      await tester.pump();
      expect(find.textContaining('at least 8 characters'), findsWidgets);
    },
  );

  testWidgets(
    'notification composer validates and states fail-closed delivery',
    (tester) async {
      api.responses['/api/v1/admin/notifications'] = {
        'deliveryInfrastructure': 'notConfigured',
        'items': <Object?>[],
      };
      await pump(tester, const CmsNotificationsScreen());
      expect(find.textContaining('Push delivery'), findsWidgets);
      await tester.tap(find.text('Create in-app record'));
      await tester.pump();
      expect(find.textContaining('required'), findsOneWidget);
    },
  );

  testWidgets('admin actions expose confirmations and self safeguards', (
    tester,
  ) async {
    api.responses['/api/v1/admin/super/admins'] = {
      'items': [
        {
          'id': 'super-1',
          'email': 'self@example.com',
          'displayName': 'Self',
          'role': 'super_admin',
          'isActive': true,
        },
        {
          'id': 'admin-2',
          'email': 'admin@example.com',
          'displayName': 'Admin Two',
          'role': 'admin',
          'isActive': true,
        },
      ],
    };
    await pump(tester, const CmsAdminsScreen());
    expect(find.text('Current operator'), findsOneWidget);
    expect(find.text('Change role'), findsOneWidget);
    expect(find.text('Suspend'), findsNWidgets(2));
    expect(find.text('Revoke sessions'), findsNWidgets(2));
    await tester.tap(find.text('Revoke sessions').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Target: Admin Two'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(find.textContaining('at least 8 characters'), findsWidgets);
  });

  testWidgets('commerce filters are sent and classifications are rendered', (
    tester,
  ) async {
    api.responses['/api/v1/admin/commerce'] = {
      'providerOperationsMessage': 'Provider operations unavailable.',
      'purchases': [
        {'id': 'p1', 'authority': 'providerVerified'},
      ],
      'subscriptions': [
        {'id': 's1', 'authority': 'pendingUnverified'},
      ],
      'plans': <Object?>[],
    };
    await pump(tester, const CmsCommerceScreen());
    expect(find.text('Provider Verified'), findsOneWidget);
    expect(find.text('Pending Unverified'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Learner ID'),
      'learner-9',
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(api.lastQuery['learnerId'], 'learner-9');
  });

  testWidgets('audit filters paginate and expose read-only metadata', (
    tester,
  ) async {
    api.responses['/api/v1/admin/audit-logs'] = {
      'items': [
        {
          'id': 'a1',
          'action': 'account.suspended',
          'targetId': 'u1',
          'data': {'safe': true},
        },
      ],
      'total': 40,
    };
    await pump(tester, const CmsAuditLogsScreen());
    await tester.enterText(find.widgetWithText(TextField, 'Target ID'), 'u1');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(api.lastQuery['subjectId'], 'u1');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(api.lastQuery['page'], 2);
    expect(find.text('Inspect metadata'), findsOneWidget);
    expect(find.textContaining('Edit'), findsNothing);
    expect(find.textContaining('Delete'), findsNothing);
  });
}

final class _Api implements ApiClient {
  final responses = <String, Map<String, Object?>>{};
  Map<String, Object?> lastQuery = const {};
  Map<String, Object?> lastBody = const {};

  @override
  Future<Result<Map<String, Object?>>> get(
    String path, {
    Map<String, Object?> query = const {},
    bool authenticated = true,
  }) async {
    lastQuery = query;
    return Success(responses[path] ?? {'items': <Object?>[]});
  }

  @override
  Future<Result<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async {
    lastBody = body;
    return const Success({});
  }

  @override
  Future<Result<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async => const Success({});

  @override
  Future<Result<Map<String, Object?>>> delete(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async => const Success({});
}
