import 'package:learning_platform/features/authentication/domain/auth_session.dart';
import 'package:learning_platform/features/authentication/domain/learner_identity.dart';

final class LearnerIdentityDto {
  const LearnerIdentityDto({
    required this.id,
    required this.email,
    required this.displayName,
    required this.hasCompletedOnboarding,
    this.role = 'learner',
  });

  factory LearnerIdentityDto.fromJson(Map<String, Object?> json) =>
      LearnerIdentityDto(
        id: json['id']! as String,
        email: json['email']! as String,
        displayName: json['displayName']! as String,
        hasCompletedOnboarding: json['hasCompletedOnboarding']! as bool,
        role: json['role'] as String? ?? 'learner',
      );

  factory LearnerIdentityDto.fromDomain(LearnerIdentity identity) =>
      LearnerIdentityDto(
        id: identity.id,
        email: identity.email,
        displayName: identity.displayName,
        hasCompletedOnboarding: identity.hasCompletedOnboarding,
        role: identity.role,
      );

  final String id;
  final String email;
  final String displayName;
  final bool hasCompletedOnboarding;
  final String role;

  LearnerIdentity toDomain() => LearnerIdentity(
    id: id,
    email: email,
    displayName: displayName,
    hasCompletedOnboarding: hasCompletedOnboarding,
    role: role,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'role': role,
  };
}

final class AuthSessionDto {
  const AuthSessionDto({
    required this.identity,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.sessionId,
  });

  factory AuthSessionDto.fromJson(Map<String, Object?> json) => AuthSessionDto(
    identity: LearnerIdentityDto.fromJson(
      Map<String, Object?>.from(json['identity']! as Map),
    ),
    accessToken: json['accessToken']! as String,
    refreshToken: json['refreshToken']! as String,
    expiresAt: DateTime.parse(json['expiresAt']! as String).toUtc(),
    sessionId: json['sessionId']! as String,
  );

  final LearnerIdentityDto identity;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String sessionId;

  AuthSession toDomain() => AuthSession(
    identity: identity.toDomain(),
    expiresAt: expiresAt,
    sessionId: sessionId,
  );

  Map<String, Object?> toJson() => {
    'identity': identity.toJson(),
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'sessionId': sessionId,
  };
}
