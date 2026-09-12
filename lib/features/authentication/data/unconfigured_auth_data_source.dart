import 'package:learning_platform/features/authentication/data/auth_dtos.dart';
import 'package:learning_platform/features/authentication/data/auth_remote_data_source.dart';
import 'package:learning_platform/features/authentication/domain/auth_credentials.dart';

final class UnconfiguredAuthDataSource implements AuthRemoteDataSource {
  const UnconfiguredAuthDataSource();

  @override
  Future<LearnerIdentityDto> currentIdentity(String accessToken) async =>
      _unavailable();

  Never _unavailable() => throw const AuthDataSourceException(
    AuthDataSourceErrorKind.server,
    'Authentication service is not configured.',
  );

  @override
  Future<AuthSessionDto> signIn(EmailCredentials credentials) async =>
      _unavailable();
  @override
  Future<AuthSessionDto> register(RegistrationDetails details) async =>
      _unavailable();
  @override
  Future<void> requestPasswordReset(String email) async => _unavailable();
  @override
  Future<AuthSessionDto> resetPassword(PasswordResetDetails details) async =>
      _unavailable();
  @override
  Future<AuthSessionDto> verifyOtp({
    required String email,
    required String code,
  }) async => _unavailable();
  @override
  Future<AuthSessionDto> signInWithProvider(
    ExternalIdentityProvider provider,
  ) async => _unavailable();
  @override
  Future<AuthSessionDto> refresh(String refreshToken) async => _unavailable();
  @override
  Future<AuthSessionDto> completeOnboarding({
    required String accessToken,
    required String displayName,
  }) async => _unavailable();
  @override
  Future<void> signOut({
    required String refreshToken,
    required bool allDevices,
  }) async => _unavailable();
  @override
  Future<void> deleteAccount(String accessToken) async => _unavailable();
}
