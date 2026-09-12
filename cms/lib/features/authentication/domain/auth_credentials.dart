final class EmailCredentials {
  const EmailCredentials({required this.email, required this.password});
  final String email;
  final String password;
}

final class RegistrationDetails {
  const RegistrationDetails({
    required this.email,
    required this.password,
    required this.displayName,
  });
  final String email;
  final String password;
  final String displayName;
}

final class PasswordResetDetails {
  const PasswordResetDetails({
    required this.email,
    required this.verificationCode,
    required this.newPassword,
  });

  final String email;
  final String verificationCode;
  final String newPassword;
}

enum ExternalIdentityProvider { google, apple }
