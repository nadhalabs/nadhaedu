import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/authentication/domain/auth_credentials.dart';
import 'package:learning_platform/features/authentication/domain/auth_repository.dart';
import 'package:learning_platform/features/authentication/domain/auth_session.dart';

final class AuthService {
  const AuthService(this._repository);
  final AuthRepository _repository;

  Future<Result<AuthSession?>> bootstrap() => _repository.restoreSession();
  Future<Result<AuthSession>> signIn(String email, String password) =>
      _repository.signIn(EmailCredentials(email: email, password: password));
  Future<Result<AuthSession>> register(
    String email,
    String password,
    String displayName,
  ) => _repository.register(
    RegistrationDetails(
      email: email,
      password: password,
      displayName: displayName,
    ),
  );
  Future<Result<void>> requestRecovery(String email) =>
      _repository.requestPasswordReset(email);
  Future<Result<AuthSession>> resetPassword(
    String email,
    String verificationCode,
    String newPassword,
  ) => _repository.resetPassword(
    PasswordResetDetails(
      email: email,
      verificationCode: verificationCode,
      newPassword: newPassword,
    ),
  );
  Future<Result<AuthSession>> verifyOtp(String email, String code) =>
      _repository.verifyOtp(email: email, code: code);
  Future<Result<AuthSession>> completeOnboarding(String displayName) =>
      _repository.completeOnboarding(displayName);
  Future<Result<AuthSession>> refresh() => _repository.refreshSession();
  Future<Result<void>> signOut({bool allDevices = false}) =>
      _repository.signOut(allDevices: allDevices);
  Future<Result<void>> deleteAccount() => _repository.deleteAccount();
}
