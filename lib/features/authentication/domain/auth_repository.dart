import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/authentication/domain/auth_credentials.dart';
import 'package:learning_platform/features/authentication/domain/auth_session.dart';

abstract interface class AuthRepository {
  Future<Result<AuthSession?>> restoreSession();
  Future<Result<AuthSession>> signIn(EmailCredentials credentials);
  Future<Result<AuthSession>> register(RegistrationDetails details);
  Future<Result<void>> requestPasswordReset(String email);
  Future<Result<AuthSession>> resetPassword(PasswordResetDetails details);
  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String code,
  });
  Future<Result<AuthSession>> signInWithProvider(
    ExternalIdentityProvider provider,
  );
  Future<Result<AuthSession>> refreshSession();
  Future<Result<AuthSession>> completeOnboarding(String displayName);
  Future<Result<void>> signOut({bool allDevices = false});
  Future<Result<void>> deleteAccount();
}
