import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/config/branding_config.dart';

void main() {
  test('Nadha Edu UI branding is centralized', () {
    expect(BrandingConfig.temporary.displayName, 'Nadha Edu');
    expect(BrandingConfig.temporary.wordmark, 'NADHA EDU');
  });
}
