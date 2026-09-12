import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/features/authentication/application/auth_controller.dart';
import 'package:learning_platform/features/authentication/application/auth_service.dart';
import 'package:learning_platform/features/authentication/application/auth_state.dart';
import 'package:learning_platform/features/authentication/domain/auth_session.dart';
import 'package:learning_platform/features/authentication/domain/learner_identity.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  test(
    'bootstrap moves to unauthenticated without a persisted session',
    () async {
      final controller = AuthController(AuthService(FakeAuthRepository()));
      await controller.bootstrap();
      expect(controller.state.status, AuthStatus.unauthenticated);
    },
  );

  test('successful registration requires onboarding', () async {
    final repository = FakeAuthRepository()
      ..nextSession = _session(hasCompletedOnboarding: false);
    final controller = AuthController(AuthService(repository));
    await controller.bootstrap();

    final success = await controller.register(
      'learner@example.com',
      'long-password',
      'Learner',
    );

    expect(success, isTrue);
    expect(controller.state.status, AuthStatus.onboardingRequired);
  });

  test('successful login with onboarded identity is authenticated', () async {
    final repository = FakeAuthRepository()
      ..nextSession = _session(hasCompletedOnboarding: true);
    final controller = AuthController(AuthService(repository));
    await controller.bootstrap();

    await controller.signIn('learner@example.com', 'long-password');

    expect(controller.state.status, AuthStatus.authenticated);
    expect(repository.signInCalls, 1);
  });
}

AuthSession _session({required bool hasCompletedOnboarding}) => AuthSession(
  identity: LearnerIdentity(
    id: 'learner-1',
    email: 'learner@example.com',
    displayName: 'Learner',
    hasCompletedOnboarding: hasCompletedOnboarding,
  ),
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  sessionId: 'session-1',
);
