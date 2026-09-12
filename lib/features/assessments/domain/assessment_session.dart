final class AssessmentAttemptSession {
  const AssessmentAttemptSession({
    required this.attemptId,
    required this.assessmentId,
    required this.startedAt,
    required this.serverNow,
    required this.expiresAt,
    required this.attemptNumber,
  });

  final String attemptId;
  final String assessmentId;
  final DateTime startedAt;
  final DateTime serverNow;
  final DateTime? expiresAt;
  final int attemptNumber;

  Duration? remainingAt(DateTime clientNow) {
    final deadline = expiresAt;
    if (deadline == null) return null;
    final estimatedServerNow = serverNow.add(clientNow.difference(startedAt));
    final remaining = deadline.difference(estimatedServerNow);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
