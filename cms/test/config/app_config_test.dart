import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/config/app_config.dart';
import 'package:nadha_cms/config/app_environment.dart';

void main() {
  test('development CMS has an independently configurable backend default', () {
    final config = AppConfig.fromEnvironment(AppEnvironment.development);
    expect(config.apiBaseUri, Uri.parse('http://localhost:8000'));
    expect(config.environment, AppEnvironment.development);
  });
}
