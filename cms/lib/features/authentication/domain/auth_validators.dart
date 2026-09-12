abstract final class AuthValidators {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return 'Enter your email address.';
    if (!_emailPattern.hasMatch(normalized)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (value.length < 12) return 'Use at least 12 characters.';
    return null;
  }

  static String? displayName(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.length < 2) return 'Enter at least 2 characters.';
    if (normalized.length > 80) return 'Use 80 characters or fewer.';
    return null;
  }

  static String? otp(String? value) {
    if (!RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')) {
      return 'Enter the 6-digit code.';
    }
    return null;
  }
}
