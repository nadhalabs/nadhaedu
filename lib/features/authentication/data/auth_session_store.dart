import 'dart:convert';

import 'package:learning_platform/core/security/secure_store.dart';
import 'package:learning_platform/features/authentication/data/auth_dtos.dart';

abstract interface class AuthSessionStore {
  Future<AuthSessionDto?> read();
  Future<void> write(AuthSessionDto session);
  Future<void> clear();
}

final class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore(this._secureStore);

  static const _sessionKey = 'authentication.session.v1';
  final SecureStore _secureStore;

  @override
  Future<AuthSessionDto?> read() async {
    final encoded = await _secureStore.read(_sessionKey);
    if (encoded == null) return null;
    final json = jsonDecode(encoded);
    if (json is! Map<String, Object?>) return null;
    return AuthSessionDto.fromJson(json);
  }

  @override
  Future<void> write(AuthSessionDto session) =>
      _secureStore.write(_sessionKey, jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _secureStore.remove(_sessionKey);
}
