import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_config.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/features/authentication/application/auth_controller.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/authentication/application/auth_service.dart';
import 'package:learning_platform/features/authentication/presentation/login_screen.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  testWidgets('validates required sign-in fields without calling repository', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final controller = AuthController(AuthService(repository));
    await controller.bootstrap();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(AppEnvironment.development),
          ),
          authControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(repository.signInCalls, 0);
  });

  testWidgets('password field supplies platform autofill semantics', (
    tester,
  ) async {
    final controller = AuthController(AuthService(FakeAuthRepository()));
    await controller.bootstrap();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(AppEnvironment.development),
          ),
          authControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.last.autofillHints, contains(AutofillHints.password));
    expect(find.byTooltip('Show password'), findsOneWidget);
  });
}
