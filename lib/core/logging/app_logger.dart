import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

abstract interface class AppLogger {
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  });
}

final class DeveloperAppLogger implements AppLogger {
  const DeveloperAppLogger({required this.enabled});

  final bool enabled;

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled && level == LogLevel.debug) return;
    developer.log(
      '$message ${context.isEmpty ? '' : context}',
      name: 'learning_platform',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
      time: DateTime.now().toUtc(),
    );
  }
}
