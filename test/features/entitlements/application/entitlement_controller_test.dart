import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_controller.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_repository.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

final class _StaleRepository implements EntitlementRepository {
  @override
  bool get isCacheStale => true;

  @override
  Future<List<Entitlement>> getEntitlements({
    bool forceRefresh = false,
  }) async => const [];

  @override
  Future<void> refreshEntitlements() async {}

  @override
  Stream<List<Entitlement>> watchEntitlements() => const Stream.empty();

  @override
  Future<AccessDecision> evaluateAccess({
    required ResourceType resourceType,
    required String resourceId,
    required AccessPolicy policy,
    Set<String>? categoryIds,
    String? courseId,
  }) => throw UnimplementedError();
}

void main() {
  test('controller preserves stale-cache provenance', () async {
    final controller = EntitlementController(_StaleRepository());

    await controller.load();

    expect(controller.state.isStale, isTrue);
    expect(controller.state.failure, isNull);
  });
}
