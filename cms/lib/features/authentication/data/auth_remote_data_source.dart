import 'package:nadha_cms/features/authentication/data/auth_dtos.dart';
import 'package:nadha_cms/features/authentication/domain/auth_credentials.dart';

enum AuthDataSourceErrorKind {
  invalidCredentials,
  validation,
  unauthorized,
  offline,
  timeout,
  server,
  unsupported,
}

final class AuthDataSourceException implements Exception {
  const AuthDataSourceException(this.kind, this.message);
  final AuthDataSourceErrorKind kind;
  final String message;
}

abstract interface class AuthRemoteDataSource {
  Future<LearnerIdentityDto> currentIdentity(String accessToken);
  Future<AuthSessionDto> signIn(EmailCredentials credentials);
  Future<AuthSessionDto> register(RegistrationDetails details);
  Future<void> requestPasswordReset(String email);
  Future<AuthSessionDto> resetPassword(PasswordResetDetails details);
  Future<AuthSessionDto> verifyOtp({
    required String email,
    required String code,
  });
  Future<AuthSessionDto> signInWithProvider(ExternalIdentityProvider provider);
  Future<AuthSessionDto> refresh(String refreshToken);
  Future<AuthSessionDto> completeOnboarding({
    required String accessToken,
    required String displayName,
  });
  Future<void> signOut({
    required String refreshToken,
    required bool allDevices,
  });
  Future<void> deleteAccount(String accessToken);
}
