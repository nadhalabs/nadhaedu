import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/authentication/data/auth_dtos.dart';
import 'package:learning_platform/features/authentication/data/auth_remote_data_source.dart';
import 'package:learning_platform/features/authentication/data/auth_session_store.dart';
import 'package:learning_platform/features/authentication/domain/auth_credentials.dart';
import 'package:learning_platform/features/authentication/domain/auth_failure.dart';
import 'package:learning_platform/features/authentication/domain/auth_repository.dart';
import 'package:learning_platform/features/authentication/domain/auth_session.dart';

final class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthSessionStore sessionStore,
  }) : _remote = remote,
       _sessionStore = sessionStore;

  final AuthRemoteDataSource _remote;
  final AuthSessionStore _sessionStore;

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    try {
      final stored = await _sessionStore.read();
      if (stored == null) return const Success(null);
      if (stored.expiresAt.isAfter(DateTime.now().toUtc())) {
        final identity = await _remote.currentIdentity(stored.accessToken);
        final validated = AuthSessionDto(
          identity: identity,
          accessToken: stored.accessToken,
          refreshToken: stored.refreshToken,
          expiresAt: stored.expiresAt,
          sessionId: stored.sessionId,
        );
        await _sessionStore.write(validated);
        return Success(validated.toDomain());
      }
      final refreshed = await _remote.refresh(stored.refreshToken);
      await _sessionStore.write(refreshed);
      return Success(refreshed.toDomain());
    } on AuthDataSourceException catch (error) {
      if (error.kind == AuthDataSourceErrorKind.unauthorized) {
        await _sessionStore.clear();
        return const Failure(AuthExpiredFailure());
      }
      return Failure(_mapFailure(error));
    } on Exception catch (error) {
      return Failure(
        StorageFailure(
          code: 'session_restore_failed',
          message: 'The saved session could not be read.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<AuthSession>> signIn(EmailCredentials credentials) =>
      _createSession(() => _remote.signIn(credentials));

  @override
  Future<Result<AuthSession>> register(RegistrationDetails details) =>
      _createSession(() => _remote.register(details));

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String code,
  }) => _createSession(() => _remote.verifyOtp(email: email, code: code));

  @override
  Future<Result<AuthSession>> signInWithProvider(
    ExternalIdentityProvider provider,
  ) => _createSession(() => _remote.signInWithProvider(provider));

  @override
  Future<Result<void>> requestPasswordReset(String email) async {
    try {
      await _remote.requestPasswordReset(email);
      return const Success(null);
    } on AuthDataSourceException catch (error) {
      return Failure(_mapFailure(error));
    }
  }

  @override
  Future<Result<AuthSession>> resetPassword(PasswordResetDetails details) =>
      _createSession(() => _remote.resetPassword(details));

  @override
  Future<Result<AuthSession>> refreshSession() async {
    final stored = await _sessionStore.read();
    if (stored == null) return const Failure(AuthExpiredFailure());
    try {
      final refreshed = await _remote.refresh(stored.refreshToken);
      await _sessionStore.write(refreshed);
      return Success(refreshed.toDomain());
    } on AuthDataSourceException catch (error) {
      if (error.kind == AuthDataSourceErrorKind.unauthorized) {
        await _sessionStore.clear();
      }
      return Failure(_mapFailure(error));
    }
  }

  @override
  Future<Result<AuthSession>> completeOnboarding(String displayName) async {
    final stored = await _sessionStore.read();
    if (stored == null) return const Failure(AuthExpiredFailure());
    return _createSession(
      () => _remote.completeOnboarding(
        accessToken: stored.accessToken,
        displayName: displayName,
      ),
    );
  }

  @override
  Future<Result<void>> signOut({bool allDevices = false}) async {
    final stored = await _sessionStore.read();
    try {
      if (stored != null) {
        await _remote.signOut(
          refreshToken: stored.refreshToken,
          allDevices: allDevices,
        );
      }
    } on AuthDataSourceException catch (error) {
      if (error.kind != AuthDataSourceErrorKind.unauthorized) {
        return Failure(_mapFailure(error));
      }
    }
    await _sessionStore.clear();
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteAccount() async {
    final stored = await _sessionStore.read();
    if (stored == null) return const Failure(AuthExpiredFailure());
    try {
      await _remote.deleteAccount(stored.accessToken);
      await _sessionStore.clear();
      return const Success(null);
    } on AuthDataSourceException catch (error) {
      if (error.kind == AuthDataSourceErrorKind.unauthorized) {
        await _sessionStore.clear();
      }
      return Failure(_mapFailure(error));
    }
  }

  Future<Result<AuthSession>> _createSession(
    Future<AuthSessionDto> Function() operation,
  ) async {
    try {
      final dto = await operation();
      await _sessionStore.write(dto);
      return Success(dto.toDomain());
    } on AuthDataSourceException catch (error) {
      return Failure(_mapFailure(error));
    } on Exception catch (error) {
      return Failure(
        StorageFailure(
          code: 'session_persist_failed',
          message: 'The secure session could not be saved.',
          cause: error,
        ),
      );
    }
  }

  AppFailure _mapFailure(AuthDataSourceException error) => switch (error.kind) {
    AuthDataSourceErrorKind.invalidCredentials =>
      const InvalidCredentialsFailure(),
    AuthDataSourceErrorKind.validation => AuthValidationFailure(
      code: 'authentication_validation',
      message: error.message,
    ),
    AuthDataSourceErrorKind.unauthorized => const AuthExpiredFailure(),
    AuthDataSourceErrorKind.unsupported => const UnsupportedAuthMethodFailure(),
    AuthDataSourceErrorKind.offline => AuthUnavailableFailure(
      code: 'offline',
      message: 'You appear to be offline.',
      cause: error,
    ),
    AuthDataSourceErrorKind.timeout => AuthUnavailableFailure(
      code: 'timeout',
      message: 'The request timed out. Please retry.',
      cause: error,
    ),
    AuthDataSourceErrorKind.server => AuthUnavailableFailure(
      code: 'server_failure',
      message: 'The service is temporarily unavailable.',
      cause: error,
    ),
  };
}
