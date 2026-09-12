import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

abstract interface class EntitlementRepository {
  /// Whether the current repository value came from local fallback storage.
  bool get isCacheStale;

  /// Loads all current learner entitlements. Returns cached copy with background refresh
  /// unless [forceRefresh] is true.
  Future<List<Entitlement>> getEntitlements({bool forceRefresh = false});

  /// Streams updates to the learner's entitlements.
  Stream<List<Entitlement>> watchEntitlements();

  /// Evaluates an access decision for the specified resource.
  Future<AccessDecision> evaluateAccess({
    required ResourceType resourceType,
    required String resourceId,
    required AccessPolicy policy,
    Set<String>? categoryIds,
    String? courseId,
  });

  /// Forces a fresh retrieval of entitlements from the authoritative remote data source.
  Future<void> refreshEntitlements();
}
