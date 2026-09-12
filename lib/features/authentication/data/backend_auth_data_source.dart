import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/authentication/data/auth_dtos.dart';
import 'package:learning_platform/features/authentication/data/auth_remote_data_source.dart';
import 'package:learning_platform/features/authentication/domain/auth_credentials.dart';

final class BackendAuthDataSource implements AuthRemoteDataSource {
  const BackendAuthDataSource(this._client);
  final ApiClient _client;

  @override
  Future<LearnerIdentityDto> currentIdentity(String accessToken) async {
    final json = switch (await _client.get('/api/v1/auth/me')) {
      Success(value: final value) => value,
      Failure(failure: final failure) => throw _authException(failure),
    };
    return LearnerIdentityDto.fromJson(json);
  }

  @override
  Future<AuthSessionDto> signIn(EmailCredentials value) => _session(
    _post('/api/v1/auth/login', {
      'email': value.email,
      'password': value.password,
    }, authenticated: false),
  );
  @override
  Future<AuthSessionDto> register(RegistrationDetails value) => _session(
    _post('/api/v1/auth/register', {
      'email': value.email,
      'password': value.password,
      'displayName': value.displayName,
    }, authenticated: false),
  );
  @override
  Future<AuthSessionDto> refresh(String refreshToken) => _session(
    _post('/api/v1/auth/refresh', {
      'refreshToken': refreshToken,
    }, authenticated: false),
  );
  @override
  Future<void> requestPasswordReset(String email) async {
    await _post('/api/v1/auth/password-reset/request', {
      'email': email,
    }, authenticated: false);
  }

  @override
  Future<AuthSessionDto> resetPassword(PasswordResetDetails value) => _session(
    _post('/api/v1/auth/password-reset/confirm', {
      'email': value.email,
      'verificationCode': value.verificationCode,
      'newPassword': value.newPassword,
    }, authenticated: false),
  );
  @override
  Future<AuthSessionDto> completeOnboarding({
    required String accessToken,
    required String displayName,
  }) =>
      _session(_post('/api/v1/auth/onboarding', {'displayName': displayName}));
  @override
  Future<void> signOut({
    required String refreshToken,
    required bool allDevices,
  }) async {
    await _post('/api/v1/auth/logout', {
      'refreshToken': refreshToken,
      'allDevices': allDevices,
    });
  }

  @override
  Future<void> deleteAccount(String accessToken) async {
    await _post('/api/v1/auth/delete-account', const {});
  }

  @override
  Future<AuthSessionDto> verifyOtp({
    required String email,
    required String code,
  }) async => throw const AuthDataSourceException(
    AuthDataSourceErrorKind.unsupported,
    'OTP authentication is not enabled.',
  );
  @override
  Future<AuthSessionDto> signInWithProvider(
    ExternalIdentityProvider provider,
  ) async => throw const AuthDataSourceException(
    AuthDataSourceErrorKind.unsupported,
    'External authentication is not enabled.',
  );

  Future<AuthSessionDto> _session(Future<Map<String, Object?>> value) async =>
      AuthSessionDto.fromJson(await value);
  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body, {
    bool authenticated = true,
  }) async => switch (await _client.post(
    path,
    body: body,
    authenticated: authenticated,
  )) {
    Success(value: final value) => value,
    Failure(failure: final failure) => throw _authException(failure),
  };
}

AuthDataSourceException _authException(Object failure) {
  if (failure case ApiFailure(
    kind: final kind,
    message: final message,
    code: final code,
  )) {
    final mapped = switch (kind) {
      ApiErrorKind.authenticationRequired =>
        code == 'INVALID_CREDENTIALS'
            ? AuthDataSourceErrorKind.invalidCredentials
            : AuthDataSourceErrorKind.unauthorized,
      ApiErrorKind.validation ||
      ApiErrorKind.conflict => AuthDataSourceErrorKind.validation,
      ApiErrorKind.offline => AuthDataSourceErrorKind.offline,
      ApiErrorKind.timeout => AuthDataSourceErrorKind.timeout,
      _ => AuthDataSourceErrorKind.server,
    };
    return AuthDataSourceException(mapped, message);
  }
  return const AuthDataSourceException(
    AuthDataSourceErrorKind.server,
    'Authentication service is unavailable.',
  );
}
