import 'package:learning_platform/core/errors/app_failure.dart';

final class InvalidCredentialsFailure extends AppFailure {
  const InvalidCredentialsFailure()
    : super(
        code: 'invalid_credentials',
        message: 'The email or password is incorrect.',
      );
}

final class AuthValidationFailure extends AppFailure {
  const AuthValidationFailure({required super.code, required super.message});
}

final class AuthExpiredFailure extends AppFailure {
  const AuthExpiredFailure()
    : super(
        code: 'authentication_expired',
        message: 'Your session has expired.',
      );
}

final class AuthUnavailableFailure extends AppFailure {
  const AuthUnavailableFailure({
    required super.code,
    required super.message,
    super.cause,
  });
}

final class UnsupportedAuthMethodFailure extends AppFailure {
  const UnsupportedAuthMethodFailure()
    : super(
        code: 'unsupported_auth_method',
        message: 'This sign-in method is not available.',
      );
}
