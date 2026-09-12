import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/persistence/key_value_store.dart';
import 'package:learning_platform/features/settings/data/settings_repository.dart';
import 'package:learning_platform/features/settings/domain/app_settings.dart';

import '../../../helpers/memory_key_value_store.dart';

final class _FailingReadStore implements KeyValueStore {
  @override
  Future<String?> readString(String key) => throw StateError('unavailable');

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> writeString(String key, String value) async {}
}

void main() {
  group('SettingsRepositoryImpl', () {
    late MemoryKeyValueStore memoryStore;
    late SettingsRepositoryImpl repository;

    setUp(() {
      memoryStore = MemoryKeyValueStore();
      repository = SettingsRepositoryImpl(memoryStore);
    });

    test('loads default settings when store is empty', () async {
      final settings = await repository.loadSettings();
      expect(settings.appearance.themeMode, ThemeMode.system);
      expect(settings.playback.autoplayNextLesson, isTrue);
      expect(settings.downloads.downloadWifiOnly, isTrue);
    });

    test('saves and loads settings correctly', () async {
      const custom = AppSettings(
        appearance: AppearanceSettings(
          themeMode: ThemeMode.dark,
          reducedMotion: true,
        ),
        playback: PlaybackSettings(
          autoplayNextLesson: false,
          preferredPlaybackSpeed: 1.5,
        ),
        downloads: DownloadPreferences(
          downloadQuality: '1080p',
          downloadWifiOnly: false,
        ),
      );

      final saveResult = await repository.saveSettings(custom);
      expect(saveResult, isA<Success<void>>());

      final loaded = await repository.loadSettings();
      expect(loaded.appearance.themeMode, ThemeMode.dark);
      expect(loaded.appearance.reducedMotion, isTrue);
      expect(loaded.playback.autoplayNextLesson, isFalse);
      expect(loaded.playback.preferredPlaybackSpeed, 1.5);
      expect(loaded.downloads.downloadQuality, '1080p');
      expect(loaded.downloads.downloadWifiOnly, isFalse);
    });

    test('uses safe defaults when local storage cannot be read', () async {
      final unavailableRepository = SettingsRepositoryImpl(_FailingReadStore());

      final loaded = await unavailableRepository.loadSettings();

      expect(loaded.appearance.themeMode, ThemeMode.system);
      expect(loaded.downloads.downloadWifiOnly, isTrue);
    });
  });
}
