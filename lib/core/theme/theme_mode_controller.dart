import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/features/settings/application/settings_providers.dart';

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(
    settingsControllerProvider.select((s) => s.appearance.themeMode),
  );
});
