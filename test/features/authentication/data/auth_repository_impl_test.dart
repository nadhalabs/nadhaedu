import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/authentication/data/auth_dtos.dart';
import 'package:learning_platform/features/authentication/data/auth_remote_data_source.dart';
import 'package:learning_platform/features/authentication/data/auth_repository_impl.dart';
import 'package:learning_platform/features/authentication/data/auth_session_store.dart';
import 'package:learning_platform/features/authentication/domain/auth_credentials.dart';

void main() {
  test(
    'validates an unexpired persisted session with current-user authority',
    () async {
      final stored = _session(
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 30)),
      );
      final remote = _Remote();
      final repository = AuthRepositoryImpl(
        remote: remote,
        sessionStore: _Store(stored),
      );

      final result = await repository.restoreSession();

      expect(result, isA<Success>());
      expect(remote.refreshCalls, 0);
    },
  );

  test(
    'does not clear persisted tokens on a temporary refresh failure',
    () async {
      final store = _Store(
        _session(
          expiresAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        ),
      );
      final remote = _Remote(
        refreshError: const AuthDataSourceException(
          AuthDataSourceErrorKind.offline,
          'offline',
        ),
      );
      final repository = AuthRepositoryImpl(
        remote: remote,
        sessionStore: store,
      );

      final result = await repository.restoreSession();

      expect(result, isA<Failure>());
      expect(store.clearCalls, 0);
      expect(store.value, isNotNull);
    },
  );

  test('clears persisted tokens when server confirms invalidation', () async {
    final store = _Store(
      _session(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      ),
    );
    final remote = _Remote(
      refreshError: const AuthDataSourceException(
        AuthDataSourceErrorKind.unauthorized,
        'invalid',
      ),
    );
    final repository = AuthRepositoryImpl(remote: remote, sessionStore: store);

    await repository.restoreSession();

    expect(store.clearCalls, 1);
    expect(store.value, isNull);
  });
}

AuthSessionDto _session({required DateTime expiresAt}) => AuthSessionDto(
  identity: const LearnerIdentityDto(
    id: 'learner-1',
    email: 'learner@example.com',
    displayName: 'Learner',
    hasCompletedOnboarding: true,
  ),
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  expiresAt: expiresAt,
  sessionId: 'session-1',
);

final class _Store implements AuthSessionStore {
  _Store(this.value);
  AuthSessionDto? value;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
    value = null;
  }

  @override
  Future<AuthSessionDto?> read() async => value;

  @override
  Future<void> write(AuthSessionDto session) async => value = session;
}

final class _Remote implements AuthRemoteDataSource {
  _Remote({this.refreshError});
  final AuthDataSourceException? refreshError;
  int refreshCalls = 0;

  @override
  Future<LearnerIdentityDto> currentIdentity(String accessToken) async =>
      _session(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ).identity;

  @override
  Future<AuthSessionDto> refresh(String refreshToken) async {
    refreshCalls++;
    if (refreshError case final error?) throw error;
    return _session(
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<AuthSessionDto> completeOnboarding({
    required String accessToken,
    required String displayName,
  }) => throw UnimplementedError();
  @override
  Future<void> deleteAccount(String accessToken) => throw UnimplementedError();
  @override
  Future<AuthSessionDto> register(RegistrationDetails details) =>
      throw UnimplementedError();
  @override
  Future<AuthSessionDto> resetPassword(PasswordResetDetails details) =>
      throw UnimplementedError();
  @override
  Future<void> requestPasswordReset(String email) => throw UnimplementedError();
  @override
  Future<AuthSessionDto> signIn(EmailCredentials credentials) =>
      throw UnimplementedError();
  @override
  Future<AuthSessionDto> signInWithProvider(
    ExternalIdentityProvider provider,
  ) => throw UnimplementedError();
  @override
  Future<void> signOut({
    required String refreshToken,
    required bool allDevices,
  }) => throw UnimplementedError();
  @override
  Future<AuthSessionDto> verifyOtp({
    required String email,
    required String code,
  }) => throw UnimplementedError();
}
