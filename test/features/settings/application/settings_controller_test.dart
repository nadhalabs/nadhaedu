import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/settings/application/settings_controller.dart';
import 'package:learning_platform/features/settings/data/settings_repository.dart';
import 'package:learning_platform/features/settings/domain/app_settings.dart';

final class _FakeSettingsRepository implements SettingsRepository {
  AppSettings settings = const AppSettings();
  Result<void> result = const Success(null);
  final List<AppSettings> writes = [];

  @override
  Future<AppSettings> loadSettings() async => settings;

  @override
  Future<Result<void>> saveSettings(AppSettings updated) async {
    writes.add(updated);
    if (result is Failure<void>) return result;
    settings = updated;
    return result;
  }
}

void main() {
  group('SettingsController', () {
    late _FakeSettingsRepository repository;

    setUp(() {
      repository = _FakeSettingsRepository();
    });

    test('initializes and loads settings', () async {
      repository.settings = const AppSettings(
        appearance: AppearanceSettings(themeMode: ThemeMode.dark),
      );

      final controller = SettingsController(repository);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.appearance.themeMode, ThemeMode.dark);
    });

    test('updates theme mode and persists', () async {
      final controller = SettingsController(repository);
      await Future<void>.delayed(Duration.zero);

      await controller.setThemeMode(ThemeMode.dark);

      expect(controller.state.appearance.themeMode, ThemeMode.dark);
      expect(repository.settings.appearance.themeMode, ThemeMode.dark);
    });

    test('updates download preferences and persists', () async {
      final controller = SettingsController(repository);
      await Future<void>.delayed(Duration.zero);

      await controller.setDownloadQuality('1080p');
      await controller.setDownloadWifiOnly(false);

      expect(controller.state.downloads.downloadQuality, '1080p');
      expect(controller.state.downloads.downloadWifiOnly, isFalse);
      expect(repository.settings.downloads.downloadQuality, '1080p');
      expect(repository.settings.downloads.downloadWifiOnly, isFalse);
    });

    test('updates accessibility and playback options', () async {
      final controller = SettingsController(repository);
      await Future<void>.delayed(Duration.zero);

      await controller.setReducedMotion(true);
      await controller.setHighContrast(true);
      await controller.setPreferredPlaybackSpeed(1.25);
      await controller.setAutoplayNextLesson(false);

      expect(controller.state.appearance.reducedMotion, isTrue);
      expect(controller.state.appearance.highContrast, isTrue);
      expect(controller.state.playback.preferredPlaybackSpeed, 1.25);
      expect(controller.state.playback.autoplayNextLesson, isFalse);
    });

    test(
      'rolls back an optimistic update when local persistence fails',
      () async {
        repository.result = Failure(
          StorageFailure(code: 'WRITE_FAILED', message: 'disk full'),
        );
        final controller = SettingsController(repository);
        await Future<void>.delayed(Duration.zero);

        await controller.setThemeMode(ThemeMode.dark);

        expect(controller.state.appearance.themeMode, ThemeMode.system);
        expect(repository.settings.appearance.themeMode, ThemeMode.system);
      },
    );

    test(
      'serializes concurrent writes and preserves the latest settings',
      () async {
        final controller = SettingsController(repository);
        await Future<void>.delayed(Duration.zero);

        await Future.wait([
          controller.setThemeMode(ThemeMode.dark),
          controller.setDownloadWifiOnly(false),
        ]);

        expect(repository.writes, hasLength(2));
        expect(repository.settings.appearance.themeMode, ThemeMode.dark);
        expect(repository.settings.downloads.downloadWifiOnly, isFalse);
      },
    );
  });
}
