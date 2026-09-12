abstract base class AppFailure implements Exception {
  const AppFailure({required this.code, required this.message, this.cause});

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    required super.code,
    required super.message,
    super.cause,
  });
}

final class StorageFailure extends AppFailure {
  const StorageFailure({
    required super.code,
    required super.message,
    super.cause,
  });
}

final class ConfigurationFailure extends AppFailure {
  const ConfigurationFailure({
    required super.code,
    required super.message,
    super.cause,
  });
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.code,
    required super.message,
    super.cause,
  });
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    required super.code,
    required super.message,
    super.cause,
  });
}

final class AuthFailure extends AppFailure {
  const AuthFailure({required super.code, required super.message, super.cause});
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({
    required super.code,
    required super.message,
    super.cause,
  });
}
