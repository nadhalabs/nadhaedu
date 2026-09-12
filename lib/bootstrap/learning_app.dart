import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_theme.dart';
import 'package:learning_platform/core/theme/theme_mode_controller.dart';
import 'package:learning_platform/features/settings/application/settings_providers.dart';

class LearningApp extends ConsumerWidget {
  const LearningApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingConfigProvider);
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp.router(
      title: branding.displayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        highContrast: settings.appearance.highContrast,
        largeTargets: settings.accessibility.largeTouchTargets,
      ),
      darkTheme: AppTheme.dark(
        highContrast: settings.appearance.highContrast,
        largeTargets: settings.accessibility.largeTouchTargets,
      ),
      themeMode: ref.watch(themeModeProvider),
      highContrastTheme: AppTheme.light(highContrast: true),
      highContrastDarkTheme: AppTheme.dark(highContrast: true),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations:
                media.disableAnimations || settings.appearance.reducedMotion,
            accessibleNavigation:
                media.accessibleNavigation ||
                settings.accessibility.screenReaderOptimized,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
