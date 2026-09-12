import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

enum EntitlementErrorKind {
  unauthenticated,
  forbidden,
  notFound,
  network,
  unconfigured,
  unknown,
}

final class EntitlementDataException implements Exception {
  const EntitlementDataException(this.kind, [this.message = '']);

  final EntitlementErrorKind kind;
  final String message;

  @override
  String toString() => 'EntitlementDataException($kind): $message';
}

abstract interface class EntitlementDataSource {
  /// Fetches the authoritative list of entitlements from the backend for the learner.
  Future<List<Entitlement>> fetchEntitlements(String learnerId);

  /// Server-side authoritative verification whether [learnerId] is permitted to access [targetId].
  Future<bool> verifyAccess({
    required String learnerId,
    required ResourceType resourceType,
    required String targetId,
    required AccessPolicy effectivePolicy,
    Set<String>? categoryIds,
    String? courseId,
  });

  Future<AccessDecision> fetchAccessDecision({
    required String learnerId,
    required ResourceType resourceType,
    required String targetId,
    required AccessPolicy effectivePolicy,
    Set<String>? categoryIds,
    String? courseId,
  });
}
