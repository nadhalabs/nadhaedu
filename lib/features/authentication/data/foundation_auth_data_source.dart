import 'package:learning_platform/features/authentication/data/auth_dtos.dart';
import 'package:learning_platform/features/authentication/data/auth_remote_data_source.dart';
import 'package:learning_platform/features/authentication/domain/auth_credentials.dart';

/// A deterministic development adapter. Replace at bootstrap when the backend
/// authentication contract is available; no feature code depends on it.
final class FoundationAuthDataSource implements AuthRemoteDataSource {
  final Map<String, _Account> _accounts = {};
  AuthSessionDto? _activeSession;

  @override
  Future<LearnerIdentityDto> currentIdentity(String accessToken) async =>
      _requireActive(accessToken).identity;

  @override
  Future<AuthSessionDto> register(RegistrationDetails details) async {
    final email = details.email.trim().toLowerCase();
    if (_accounts.containsKey(email)) {
      throw const AuthDataSourceException(
        AuthDataSourceErrorKind.validation,
        'An account already exists for this email.',
      );
    }
    _accounts[email] = _Account(
      password: details.password,
      identity: LearnerIdentityDto(
        id: 'learner-${_accounts.length + 1}',
        email: email,
        displayName: details.displayName.trim(),
        hasCompletedOnboarding: false,
      ),
    );
    return _createSession(_accounts[email]!.identity);
  }

  @override
  Future<AuthSessionDto> signIn(EmailCredentials credentials) async {
    final account = _accounts[credentials.email.trim().toLowerCase()];
    if (account == null || account.password != credentials.password) {
      throw const AuthDataSourceException(
        AuthDataSourceErrorKind.invalidCredentials,
        'Invalid credentials.',
      );
    }
    return _createSession(account.identity);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    // Deliberately does not reveal whether the account exists.
  }

  @override
  Future<AuthSessionDto> resetPassword(PasswordResetDetails details) async {
    final account = _accounts[details.email.trim().toLowerCase()];
    if (account == null || details.verificationCode != '123456') {
      throw const AuthDataSourceException(
        AuthDataSourceErrorKind.invalidCredentials,
        'The code is invalid or expired.',
      );
    }
    account.password = details.newPassword;
    return _createSession(account.identity);
  }

  @override
  Future<AuthSessionDto> verifyOtp({
    required String email,
    required String code,
  }) async {
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || code != '123456') {
      throw const AuthDataSourceException(
        AuthDataSourceErrorKind.invalidCredentials,
        'The code is invalid or expired.',
      );
    }
    return _createSession(account.identity);
  }

  @override
  Future<AuthSessionDto> signInWithProvider(
    ExternalIdentityProvider provider,
  ) async {
    throw const AuthDataSourceException(
      AuthDataSourceErrorKind.unsupported,
      'External identity providers are not configured.',
    );
  }

  @override
  Future<AuthSessionDto> refresh(String refreshToken) async {
    final active = _activeSession;
    if (active == null || active.refreshToken != refreshToken) {
      throw const AuthDataSourceException(
        AuthDataSourceErrorKind.unauthorized,
        'The session is no longer valid.',
      );
    }
    return _createSession(active.identity);
  }

  @override
  Future<AuthSessionDto> completeOnboarding({
    required String accessToken,
    required String displayName,
  }) async {
    final active = _requireActive(accessToken);
    final identity = LearnerIdentityDto(
      id: active.identity.id,
      email: active.identity.email,
      displayName: displayName.trim(),
      hasCompletedOnboarding: true,
    );
    final account = _accounts[identity.email];
    if (account != null) account.identity = identity;
    return _createSession(identity);
  }

  @override
  Future<void> signOut({
    required String refreshToken,
    required bool allDevices,
  }) async {
    _activeSession = null;
  }

  @override
  Future<void> deleteAccount(String accessToken) async {
    final active = _requireActive(accessToken);
    _accounts.remove(active.identity.email);
    _activeSession = null;
  }

  AuthSessionDto _requireActive(String accessToken) {
    final active = _activeSession;
    if (active == null || active.accessToken != accessToken) {
      throw const AuthDataSourceException(
        AuthDataSourceErrorKind.unauthorized,
        'The session is no longer valid.',
      );
    }
    return active;
  }

  AuthSessionDto _createSession(LearnerIdentityDto identity) {
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    final session = AuthSessionDto(
      identity: identity,
      accessToken: 'access-$nonce',
      refreshToken: 'refresh-$nonce',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      sessionId: 'session-$nonce',
    );
    _activeSession = session;
    return session;
  }
}

final class _Account {
  _Account({required this.password, required this.identity});
  String password;
  LearnerIdentityDto identity;
}
