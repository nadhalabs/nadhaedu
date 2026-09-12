import 'package:flutter/foundation.dart';

enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment fromBuildMode() {
    const configured = String.fromEnvironment('APP_ENV');
    if (configured.isNotEmpty) {
      return AppEnvironment.values.firstWhere(
        (value) => value.name == configured,
        orElse: () => throw FormatException(
          'APP_ENV must be development, staging, or production.',
        ),
      );
    }
    return kReleaseMode ? production : development;
  }
}
