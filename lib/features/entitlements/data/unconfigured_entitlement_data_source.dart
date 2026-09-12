import 'package:learning_platform/features/entitlements/data/entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

final class UnconfiguredEntitlementDataSource implements EntitlementDataSource {
  const UnconfiguredEntitlementDataSource();

  @override
  Future<List<Entitlement>> fetchEntitlements(String learnerId) async {
    throw const EntitlementDataException(
      EntitlementErrorKind.unconfigured,
      'Entitlement data source is not configured for this environment.',
    );
  }

  @override
  Future<bool> verifyAccess({
    required String learnerId,
    required ResourceType resourceType,
    required String targetId,
    required AccessPolicy effectivePolicy,
    Set<String>? categoryIds,
    String? courseId,
  }) async {
    throw const EntitlementDataException(
      EntitlementErrorKind.unconfigured,
      'Entitlement data source is not configured for this environment.',
    );
  }

  @override
  Future<AccessDecision> fetchAccessDecision({
    required String learnerId,
    required ResourceType resourceType,
    required String targetId,
    required AccessPolicy effectivePolicy,
    Set<String>? categoryIds,
    String? courseId,
  }) async => throw const EntitlementDataException(
    EntitlementErrorKind.unconfigured,
    'Entitlement backend is not configured.',
  );
}
