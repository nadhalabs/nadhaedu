import 'package:learning_platform/features/authentication/domain/auth_credentials.dart';

final class AuthCapabilities {
  const AuthCapabilities({
    required this.registration,
    required this.passwordRecovery,
    required this.otp,
    this.externalProviders = const {},
  });

  static const foundation = AuthCapabilities(
    registration: true,
    passwordRecovery: true,
    otp: true,
  );

  final bool registration;
  final bool passwordRecovery;
  final bool otp;
  final Set<ExternalIdentityProvider> externalProviders;
}
