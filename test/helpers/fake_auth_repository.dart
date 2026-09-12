import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/authentication/domain/auth_credentials.dart';
import 'package:learning_platform/features/authentication/domain/auth_repository.dart';
import 'package:learning_platform/features/authentication/domain/auth_session.dart';

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.restoredSession});

  AuthSession? restoredSession;
  AuthSession? nextSession;
  int signInCalls = 0;

  @override
  Future<Result<AuthSession?>> restoreSession() async =>
      Success(restoredSession);

  @override
  Future<Result<AuthSession>> signIn(EmailCredentials credentials) async {
    signInCalls++;
    return Success(nextSession!);
  }

  @override
  Future<Result<AuthSession>> register(RegistrationDetails details) async =>
      Success(nextSession!);

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String code,
  }) async => Success(nextSession!);

  @override
  Future<Result<AuthSession>> signInWithProvider(
    ExternalIdentityProvider provider,
  ) async => Success(nextSession!);

  @override
  Future<Result<AuthSession>> refreshSession() async => Success(nextSession!);

  @override
  Future<Result<AuthSession>> completeOnboarding(String displayName) async =>
      Success(nextSession!);

  @override
  Future<Result<void>> requestPasswordReset(String email) async =>
      const Success(null);

  @override
  Future<Result<AuthSession>> resetPassword(
    PasswordResetDetails details,
  ) async => Success(nextSession!);

  @override
  Future<Result<void>> signOut({bool allDevices = false}) async =>
      const Success(null);

  @override
  Future<Result<void>> deleteAccount() async => const Success(null);
}
