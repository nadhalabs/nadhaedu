import 'dart:convert';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/persistence/key_value_store.dart';
import 'package:learning_platform/features/settings/domain/app_settings.dart';

/// Manages user application preferences.
///
/// **Settings Classification**:
/// - **DEVICE LOCAL**: Theme mode, playback speed, captions, autoplay, download quality,
///   Wi-Fi-only downloads, accessibility preferences (reduced motion, high contrast).
///   Persisted locally in [KeyValueStore] without unnecessary network traffic.
/// - **ACCOUNT SYNCED**: Account notification channels and alerts (managed via
///   `NotificationPreferencesRepository` syncing with `/api/v1/notifications/preferences`).
/// - **SERVER AUTHORITATIVE**: Authentication sessions, entitlements, subscriptions,
///   certificates, and payment audit logs.
abstract interface class SettingsRepository {
  Future<AppSettings> loadSettings();
  Future<Result<void>> saveSettings(AppSettings settings);
}

final class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._store);

  final KeyValueStore _store;

  static const _storageKey = 'app_settings_v1';

  @override
  Future<AppSettings> loadSettings() async {
    try {
      final raw = await _store.readString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return AppSettings.fromJson(json);
      }
    } on Object {
      // A corrupt or temporarily unavailable local store must not prevent the
      // settings controller from initializing with safe defaults.
    }
    return const AppSettings();
  }

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async {
    try {
      final raw = jsonEncode(settings.toJson());
      await _store.writeString(_storageKey, raw);
      return const Success(null);
    } on Object catch (error) {
      return Failure(
        StorageFailure(
          code: 'SETTINGS_PERSIST_FAILED',
          message: 'Failed to persist settings: $error',
          cause: error,
        ),
      );
    }
  }
}
