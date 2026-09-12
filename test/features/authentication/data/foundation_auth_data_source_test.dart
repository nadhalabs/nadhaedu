import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/features/authentication/data/foundation_auth_data_source.dart';
import 'package:learning_platform/features/authentication/domain/auth_credentials.dart';

void main() {
  test('password reset replaces the previous development credential', () async {
    final source = FoundationAuthDataSource();
    await source.register(
      const RegistrationDetails(
        email: 'learner@example.com',
        password: 'old-password',
        displayName: 'Learner',
      ),
    );

    await source.resetPassword(
      const PasswordResetDetails(
        email: 'learner@example.com',
        verificationCode: '123456',
        newPassword: 'new-password',
      ),
    );

    final session = await source.signIn(
      const EmailCredentials(
        email: 'learner@example.com',
        password: 'new-password',
      ),
    );
    expect(session.identity.email, 'learner@example.com');
  });
}
