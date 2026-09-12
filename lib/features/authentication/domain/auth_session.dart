import 'package:learning_platform/features/authentication/domain/learner_identity.dart';

final class AuthSession {
  const AuthSession({
    required this.identity,
    required this.expiresAt,
    required this.sessionId,
  });

  final LearnerIdentity identity;
  final DateTime expiresAt;
  final String sessionId;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());
}
