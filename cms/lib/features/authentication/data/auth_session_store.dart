import 'dart:convert';

import 'package:nadha_cms/features/authentication/data/auth_dtos.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AuthSessionStore {
  Future<AuthSessionDto?> read();
  Future<void> write(AuthSessionDto session);
  Future<void> clear();
}

final class CmsWebAuthSessionStore implements AuthSessionStore {
  CmsWebAuthSessionStore(this._preferences);

  static const _sessionKey = 'authentication.session.v1';
  final SharedPreferences _preferences;

  @override
  Future<AuthSessionDto?> read() async {
    final encoded = _preferences.getString(_sessionKey);
    if (encoded == null) return null;
    final json = jsonDecode(encoded);
    if (json is! Map<String, Object?>) return null;
    return AuthSessionDto.fromJson(json);
  }

  @override
  Future<void> write(AuthSessionDto session) async {
    await _preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_sessionKey);
  }
}
