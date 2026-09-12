import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/config/app_config.dart';
import 'package:learning_platform/config/app_environment.dart';

void main() {
  test('production configuration fails closed without an API base URL', () {
    expect(
      () => AppConfig.fromEnvironment(AppEnvironment.production),
      throwsFormatException,
    );
  });

  test('development configuration enables diagnostics', () {
    final config = AppConfig.fromEnvironment(AppEnvironment.development);
    expect(config.enableDiagnostics, isTrue);
  });
}
