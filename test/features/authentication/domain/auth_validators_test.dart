import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/features/authentication/domain/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('accepts a normalized email and rejects malformed input', () {
      expect(AuthValidators.email('learner@example.com'), isNull);
      expect(AuthValidators.email('not-an-email'), isNotNull);
    });

    test('requires a minimum 12 character password', () {
      expect(AuthValidators.password('short'), isNotNull);
      expect(AuthValidators.password('long-password'), isNull);
    });

    test('requires exactly six OTP digits', () {
      expect(AuthValidators.otp('123456'), isNull);
      expect(AuthValidators.otp('12345a'), isNotNull);
    });
  });
}
