import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/core/routing/cms_router.dart';
import 'package:nadha_cms/features/authentication/application/auth_state.dart';
import 'package:nadha_cms/features/authentication/domain/auth_session.dart';
import 'package:nadha_cms/features/authentication/domain/learner_identity.dart';

void main() {
  AuthState authenticatedAs(String role) => AuthState(
    status: AuthStatus.authenticated,
    session: AuthSession(
      expiresAt: DateTime(2100),
      sessionId: 'session-1',
      identity: LearnerIdentity(
        id: 'user-1',
        email: 'user@example.com',
        displayName: 'User',
        role: role,
        hasCompletedOnboarding: true,
      ),
    ),
  );

  test('unauthenticated CMS visitor is sent to CMS sign in', () {
    expect(
      cmsRedirect(
        const AuthState(status: AuthStatus.unauthenticated),
        CmsRoutes.dashboard,
      ),
      CmsRoutes.signIn,
    );
  });

  test('authorized staff can enter admin routes', () {
    expect(cmsRedirect(authenticatedAs('admin'), CmsRoutes.dashboard), isNull);
    expect(
      cmsRedirect(authenticatedAs('content_manager'), CmsRoutes.courses),
      isNull,
    );
  });

  test('learner is rejected by standalone CMS route guard', () {
    expect(
      cmsRedirect(authenticatedAs('learner'), CmsRoutes.dashboard),
      CmsRoutes.unauthorized,
    );
  });

  test('normal admin is rejected from Ultimate Control routes', () {
    expect(
      cmsRedirect(authenticatedAs('admin'), CmsRoutes.controls),
      CmsRoutes.dashboard,
    );
    expect(
      cmsRedirect(authenticatedAs('super_admin'), CmsRoutes.controls),
      isNull,
    );
  });
}
