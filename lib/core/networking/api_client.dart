import 'dart:async';

import 'package:dio/dio.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/authentication/data/auth_dtos.dart';
import 'package:learning_platform/features/authentication/data/auth_session_store.dart';

enum ApiErrorKind {
  authenticationRequired,
  accessDenied,
  entitlementRequired,
  expiredResource,
  validation,
  conflict,
  rateLimited,
  notFound,
  offline,
  timeout,
  transientServer,
  malformedResponse,
  unknown,
}

final class ApiFailure extends AppFailure {
  const ApiFailure({
    required super.code,
    required super.message,
    required this.kind,
    this.statusCode,
    this.requestId,
    this.field,
    super.cause,
  });
  final ApiErrorKind kind;
  final int? statusCode;
  final String? requestId;
  final String? field;
}

abstract interface class ApiClient {
  Future<Result<Map<String, Object?>>> get(
    String path, {
    Map<String, Object?> query = const {},
    bool authenticated = true,
  });
  Future<Result<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  });
  Future<Result<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  });
  Future<Result<Map<String, Object?>>> delete(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  });
}

final class DioApiClient implements ApiClient {
  DioApiClient({
    required Uri baseUri,
    required AuthSessionStore sessionStore,
    Dio? dio,
    void Function()? onSessionExpired,
  }) : _sessionStore = sessionStore,
       _dio = dio ?? Dio(),
       _onSessionExpired = onSessionExpired {
    // Configure injected transports too; tests may only replace the adapter.
    _dio.options = BaseOptions(
      baseUrl: baseUri.toString(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    );
  }

  final Dio _dio;
  final void Function()? _onSessionExpired;
  void close() => _dio.close(force: true);
  final AuthSessionStore _sessionStore;
  Future<AuthSessionDto?>? _refreshInFlight;

  @override
  Future<Result<Map<String, Object?>>> get(
    String path, {
    Map<String, Object?> query = const {},
    bool authenticated = true,
  }) => _request('GET', path, query: query, authenticated: authenticated);

  @override
  Future<Result<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) => _request(
    'POST',
    path,
    body: body,
    headers: headers,
    authenticated: authenticated,
  );

  @override
  Future<Result<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) => _request(
    'PUT',
    path,
    body: body,
    headers: headers,
    authenticated: authenticated,
  );

  @override
  Future<Result<Map<String, Object?>>> delete(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) => _request(
    'DELETE',
    path,
    query: query,
    headers: headers,
    authenticated: authenticated,
  );

  Future<Result<Map<String, Object?>>> _request(
    String method,
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    required bool authenticated,
    bool mayRefresh = true,
    int retryCount = 0,
  }) async {
    AuthSessionDto? session;
    try {
      session = authenticated ? await _sessionStore.read() : null;
      final response = await _dio.request<Object?>(
        path,
        data: body.isEmpty ? null : body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            ...headers,
            if (session != null)
              'Authorization': 'Bearer ${session.accessToken}',
          },
        ),
      );
      if (response.statusCode == 204) return const Success({});
      if (response.data case final Map data) {
        return Success(Map<String, Object?>.from(data));
      }
      return Failure(_malformed(response));
    } on DioException catch (error) {
      if (authenticated &&
          mayRefresh &&
          error.response?.statusCode == 401 &&
          await _refresh(session?.accessToken) != null) {
        return _request(
          method,
          path,
          query: query,
          body: body,
          headers: headers,
          authenticated: true,
          mayRefresh: false,
        );
      }
      if (authenticated && !mayRefresh && error.response?.statusCode == 401) {
        final current = await _sessionStore.read();
        if (current?.accessToken == session?.accessToken) {
          await _sessionStore.clear();
          _onSessionExpired?.call();
        }
      }
      final kind = _mapDioFailure(error).kind;
      // Only read operations are automatically retried. Mutations retain their
      // caller-owned idempotency key and require an explicit retry.
      if (method == 'GET' &&
          retryCount < 2 &&
          {ApiErrorKind.timeout, ApiErrorKind.transientServer}.contains(kind)) {
        await Future<void>.delayed(
          Duration(milliseconds: 250 * (1 << retryCount)),
        );
        return _request(
          method,
          path,
          query: query,
          headers: headers,
          authenticated: authenticated,
          mayRefresh: mayRefresh,
          retryCount: retryCount + 1,
        );
      }
      return Failure(_mapDioFailure(error));
    } on FormatException catch (error) {
      return Failure(
        ApiFailure(
          code: 'MALFORMED_RESPONSE',
          message: 'The server response could not be read.',
          kind: ApiErrorKind.malformedResponse,
          cause: error,
        ),
      );
    }
  }

  Future<AuthSessionDto?> _refresh(String? rejectedAccessToken) {
    if (_refreshInFlight case final active?) return active;
    final operation = _performRefresh(rejectedAccessToken);
    _refreshInFlight = operation;
    return operation.whenComplete(() => _refreshInFlight = null);
  }

  Future<AuthSessionDto?> _performRefresh(String? rejectedAccessToken) async {
    final stored = await _sessionStore.read();
    if (stored == null) return null;
    if (stored.accessToken != rejectedAccessToken) return stored;
    try {
      final response = await _dio.post<Object?>(
        '/api/v1/auth/refresh',
        data: {'refreshToken': stored.refreshToken},
      );
      if (response.data case final Map data) {
        final refreshed = AuthSessionDto.fromJson(
          Map<String, Object?>.from(data),
        );
        final current = await _sessionStore.read();
        if (current?.refreshToken != stored.refreshToken) return null;
        await _sessionStore.write(refreshed);
        return refreshed;
      }
      return null;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        final current = await _sessionStore.read();
        if (current?.refreshToken == stored.refreshToken) {
          await _sessionStore.clear();
          _onSessionExpired?.call();
        }
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  ApiFailure _malformed(Response<Object?> response) => ApiFailure(
    code: 'MALFORMED_RESPONSE',
    message: 'Unexpected response format.',
    kind: ApiErrorKind.malformedResponse,
    statusCode: response.statusCode,
    requestId: response.headers.value('X-Request-ID'),
  );
  ApiFailure _mapDioFailure(DioException error) {
    final response = error.response;
    final code = _serverCode(response?.data) ?? 'REQUEST_FAILED';
    final status = response?.statusCode;
    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiErrorKind.timeout,
      DioExceptionType.connectionError => ApiErrorKind.offline,
      _ => switch (status) {
        401 => ApiErrorKind.authenticationRequired,
        403 when code.contains('ENTITLEMENT') =>
          ApiErrorKind.entitlementRequired,
        403 => ApiErrorKind.accessDenied,
        404 => ApiErrorKind.notFound,
        409 => ApiErrorKind.conflict,
        410 => ApiErrorKind.expiredResource,
        400 || 422 => ApiErrorKind.validation,
        429 => ApiErrorKind.rateLimited,
        final value? when value >= 500 => ApiErrorKind.transientServer,
        _ => ApiErrorKind.unknown,
      },
    };
    return ApiFailure(
      code: code,
      message: switch (kind) {
        ApiErrorKind.authenticationRequired =>
          code == 'INVALID_CREDENTIALS'
              ? 'The email or password doesn’t match. Please try again.'
              : 'Please sign in again to keep learning.',
        ApiErrorKind.offline =>
          'You’re offline. Open Downloads for saved lessons.',
        ApiErrorKind.timeout =>
          'This is taking a little longer. Please try again.',
        ApiErrorKind.transientServer =>
          'We’re having trouble connecting. Please try again soon.',
        ApiErrorKind.accessDenied || ApiErrorKind.entitlementRequired =>
          'This content isn’t available for your account yet.',
        ApiErrorKind.notFound || ApiErrorKind.expiredResource =>
          'This content is no longer available. Try opening it again.',
        ApiErrorKind.validation => 'Please check the information you entered.',
        ApiErrorKind.rateLimited => 'Let’s pause a moment before trying again.',
        ApiErrorKind.conflict => 'This has changed. Refresh and try again.',
        _ => 'We couldn’t finish that. Please try again.',
      },
      kind: kind,
      statusCode: status,
      requestId:
          response?.headers.value('X-Request-ID') ?? _requestId(response?.data),
      field: _field(response?.data),
      cause: error,
    );
  }
}

Map<String, Object?>? _errorEnvelope(Object? data) {
  if (data is! Map || data['error'] is! Map) return null;
  return Map<String, Object?>.from(data['error'] as Map);
}

String? _serverCode(Object? data) => switch (_errorEnvelope(data)?['code']) {
  final String value => value,
  _ => null,
};
String? _requestId(Object? data) =>
    switch (_errorEnvelope(data)?['requestId']) {
      final String value => value,
      _ => null,
    };
String? _field(Object? data) => switch (_errorEnvelope(data)?['field']) {
  final String value => value,
  _ => null,
};
