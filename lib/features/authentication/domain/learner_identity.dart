final class LearnerIdentity {
  const LearnerIdentity({
    required this.id,
    required this.email,
    required this.displayName,
    required this.hasCompletedOnboarding,
    this.role = 'learner',
  });

  final String id;
  final String email;
  final String displayName;
  final bool hasCompletedOnboarding;
  final String role;

  bool get isCmsUser =>
      role == 'admin' || role == 'content_manager' || role == 'support';
  bool get isAdmin => role == 'admin';
  bool get isContentManager => role == 'content_manager';
  bool get isSupport => role == 'support';

  LearnerIdentity copyWith({
    String? displayName,
    bool? hasCompletedOnboarding,
    String? role,
  }) => LearnerIdentity(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
    hasCompletedOnboarding:
        hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    role: role ?? this.role,
  );
}
