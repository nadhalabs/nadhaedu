import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/learning_app.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_config.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/core/crash_reporting/crash_reporter.dart';
import 'package:learning_platform/core/logging/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> bootstrap({required AppEnvironment environment}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment(environment);
  final preferences = await SharedPreferences.getInstance();
  final logger = DeveloperAppLogger(enabled: config.enableDiagnostics);
  const crashReporter = NoopCrashReporter();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.log(
      LogLevel.error,
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
    unawaited(
      crashReporter.record(
        details.exception,
        details.stack ?? StackTrace.current,
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.log(
      LogLevel.error,
      'Uncaught platform error',
      error: error,
      stackTrace: stack,
    );
    unawaited(crashReporter.record(error, stack, fatal: true));
    return true;
  };

  runApp(
    ProviderScope(
      overrides: bootstrapOverrides(config: config, preferences: preferences),
      child: const LearningApp(),
    ),
  );
}
