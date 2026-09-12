import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/branding_config.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/settings/application/settings_providers.dart';
import 'package:learning_platform/features/settings/data/settings_repository.dart';
import 'package:learning_platform/features/settings/domain/app_settings.dart';
import 'package:learning_platform/features/settings/presentation/settings_screen.dart';

import '../../../helpers/memory_key_value_store.dart';

final class _FakeSettingsRepository implements SettingsRepository {
  AppSettings settings = const AppSettings();

  @override
  Future<AppSettings> loadSettings() async => settings;

  @override
  Future<Result<void>> saveSettings(AppSettings updated) async {
    settings = updated;
    return const Success(null);
  }
}

void main() {
  testWidgets(
    'SettingsScreen renders all configuration sections and handles toggles',
    (tester) async {
      final repo = _FakeSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
            brandingConfigProvider.overrideWithValue(
              const BrandingConfig(displayName: 'Test Product'),
            ),
            settingsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings & Preferences'), findsOneWidget);
      expect(find.text('APPEARANCE & THEME'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Reduce Motion'), findsOneWidget);
      expect(find.text('High Contrast Presentation'), findsOneWidget);

      expect(find.text('LEARNING & PLAYBACK'), findsOneWidget);
      expect(find.text('Autoplay Next Lesson'), findsOneWidget);

      // Tap Reduce Motion switch
      await tester.tap(find.widgetWithText(SwitchListTile, 'Reduce Motion'));
      await tester.pumpAndSettle();

      expect(repo.settings.appearance.reducedMotion, isTrue);
    },
  );
}
