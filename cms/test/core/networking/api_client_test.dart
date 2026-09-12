import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/core/networking/api_client.dart';
import 'package:nadha_cms/features/authentication/data/auth_dtos.dart';
import 'package:nadha_cms/features/authentication/data/auth_session_store.dart';

AuthSessionDto session(String token) => AuthSessionDto(
  identity: const LearnerIdentityDto(id: 'learner', email: 'local@example.test', displayName: 'Learner', hasCompletedOnboarding: true),
  accessToken: token, refreshToken: 'refresh-$token', expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)), sessionId: token,
);

class MemorySessionStore implements AuthSessionStore {
  AuthSessionDto? value = session('old');
  @override
  Future<AuthSessionDto?> read() async => value;
  @override
  Future<void> write(AuthSessionDto session) async { value = session; }
  @override
  Future<void> clear() async { value = null; }
}

class Adapter implements HttpClientAdapter {
  Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) => handler(options);
  @override
  void close({bool force = false}) {}
}
ResponseBody response(int status, Object value) => ResponseBody.fromString(jsonEncode(value), status, headers: {Headers.contentTypeHeader: ['application/json']});
ResponseBody expired() => response(401, {'error': {'code': 'SESSION_EXPIRED', 'message': 'private server detail'}});
Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Expected asynchronous request did not arrive');
}

void main() {
  test('injected Dio retains adapter and receives base URL and timeouts', () async {
    final dio = Dio();
    RequestOptions? captured;
    dio.httpClientAdapter = Adapter((request) async { captured = request; return response(200, {}); });
    final client = DioApiClient(baseUri: Uri.parse('https://api.example.test'), sessionStore: MemorySessionStore(), dio: dio);
    await client.get('/api/v1/courses');
    expect(captured!.uri.host, 'api.example.test');
    expect(captured!.connectTimeout, const Duration(seconds: 15));
    expect(captured!.receiveTimeout, const Duration(seconds: 30));
    client.close();
  });

  test('simultaneous unauthorized requests share one refresh', () async {
    final store = MemorySessionStore();
    final gate = Completer<void>();
    var refreshes = 0;
    final dio = Dio()..httpClientAdapter = Adapter((request) async {
      if (request.path.endsWith('/refresh')) { refreshes++; await gate.future; return response(200, session('new').toJson()); }
      return request.headers['Authorization'] == 'Bearer new' ? response(200, {}) : expired();
    });
    final client = DioApiClient(baseUri: Uri.parse('https://api.example.test'), sessionStore: store, dio: dio);
    final pending = [client.get('/one'), client.get('/two'), client.get('/three')];
    await until(() => refreshes == 1);
    gate.complete();
    final results = await Future.wait(pending);
    expect(results.every((result) => result is Success), isTrue);
    expect(refreshes, 1);
    expect(store.value!.accessToken, 'new');
    client.close();
  });

  test('logout during refresh cannot resurrect the session', () async {
    final store = MemorySessionStore();
    final gate = Completer<void>();
    var refreshing = false;
    final dio = Dio()..httpClientAdapter = Adapter((request) async {
      if (request.path.endsWith('/refresh')) { refreshing = true; await gate.future; return response(200, session('new').toJson()); }
      return expired();
    });
    final client = DioApiClient(baseUri: Uri.parse('https://api.example.test'), sessionStore: store, dio: dio);
    final pending = client.get('/one');
    await until(() => refreshing);
    await store.clear();
    gate.complete();
    expect(await pending, isA<Failure>());
    expect(store.value, isNull);
    client.close();
  });

  test('authoritative refresh rejection clears storage and signals auth once', () async {
    final store = MemorySessionStore();
    var expiredEvents = 0;
    final dio = Dio()..httpClientAdapter = Adapter((_) async => expired());
    final client = DioApiClient(baseUri: Uri.parse('https://api.example.test'), sessionStore: store, dio: dio, onSessionExpired: () => expiredEvents++);
    expect(await client.get('/one'), isA<Failure>());
    expect(store.value, isNull);
    expect(expiredEvents, 1);
    client.close();
  });

  test('temporary refresh failure preserves persisted recovery material', () async {
    final store = MemorySessionStore();
    final dio = Dio()..httpClientAdapter = Adapter((request) async => request.path.endsWith('/refresh') ? response(503, {}) : expired());
    final client = DioApiClient(baseUri: Uri.parse('https://api.example.test'), sessionStore: store, dio: dio);
    expect(await client.get('/one'), isA<Failure>());
    expect(store.value!.refreshToken, 'refresh-old');
    client.close();
  });

  test('reads retry transient errors but mutations are never blindly replayed', () async {
    var gets = 0;
    var posts = 0;
    final dio = Dio()..httpClientAdapter = Adapter((request) async {
      if (request.method == 'GET' && ++gets == 3) return response(200, {});
      if (request.method == 'POST') posts++;
      return response(503, {'error': {'message': 'SQL password=secret', 'code': 42}});
    });
    final client = DioApiClient(baseUri: Uri.parse('https://api.example.test'), sessionStore: MemorySessionStore(), dio: dio);
    expect(await client.get('/read'), isA<Success>());
    final result = await client.post('/submission');
    expect(gets, 3);
    expect(posts, 1);
    expect((result as Failure).failure.message, isNot(contains('SQL')));
    client.close();
  });
}
