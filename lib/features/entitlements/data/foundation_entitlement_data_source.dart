import 'package:learning_platform/features/entitlements/data/entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_evaluator.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_source.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_status.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

/// Deterministic in-memory development adapter for freemium access and entitlements.
final class FoundationEntitlementDataSource implements EntitlementDataSource {
  FoundationEntitlementDataSource() {
    _initializeSeedData();
  }

  final Map<String, List<Entitlement>> _entitlementsByLearner = {};

  void _initializeSeedData() {
    final now = DateTime.now().toUtc();

    // 1. Default dev learner: possesses active subscription + an individual purchase
    _entitlementsByLearner['dev-learner'] = [
      Entitlement(
        id: 'ent-sub-001',
        learnerId: 'dev-learner',
        source: SubscriptionEntitlementSource(
          sourceId: 'sub-pro-001',
          planId: 'plan_pro_annual',
          tier: 'Pro',
          renewsAt: now.add(const Duration(days: 300)),
        ),
        status: EntitlementStatus.active,
        validFrom: now.subtract(const Duration(days: 65)),
        validUntil: now.add(const Duration(days: 300)),
      ),
      Entitlement(
        id: 'ent-pur-002',
        learnerId: 'dev-learner',
        source: IndividualPurchaseEntitlementSource(
          sourceId: 'ord-1002',
          orderId: 'ORD-2026-9912',
          purchasedAt: now.subtract(const Duration(days: 120)),
          amountCents: 4900,
          currencyCode: 'USD',
        ),
        status: EntitlementStatus.active,
        targetType: ResourceType.course,
        targetId: 'course-2',
        validFrom: now.subtract(const Duration(days: 120)),
        validUntil: null, // perpetual
      ),
    ];

    // 2. Expired subscription learner
    _entitlementsByLearner['expired-sub-learner'] = [
      Entitlement(
        id: 'ent-sub-exp-01',
        learnerId: 'expired-sub-learner',
        source: SubscriptionEntitlementSource(
          sourceId: 'sub-exp-01',
          planId: 'plan_pro_monthly',
          tier: 'Pro',
          renewsAt: null,
          autoRenewing: false,
        ),
        status: EntitlementStatus.expired,
        validFrom: now.subtract(const Duration(days: 60)),
        validUntil: now.subtract(const Duration(days: 5)),
      ),
    ];

    // 3. Expired trial learner
    _entitlementsByLearner['expired-trial-learner'] = [
      Entitlement(
        id: 'ent-trial-exp-01',
        learnerId: 'expired-trial-learner',
        source: const TrialEntitlementSource(
          sourceId: 'trial-01',
          trialDays: 7,
          planId: 'plan_pro_monthly',
        ),
        status: EntitlementStatus.expired,
        validFrom: now.subtract(const Duration(days: 14)),
        validUntil: now.subtract(const Duration(days: 7)),
      ),
    ];

    // 4. Scholarship recipient
    _entitlementsByLearner['scholarship-learner'] = [
      Entitlement(
        id: 'ent-sch-01',
        learnerId: 'scholarship-learner',
        source: const ScholarshipEntitlementSource(
          sourceId: 'sch-tech-2026',
          scholarshipId: 'SCH-TECH-GLOBAL',
          organizationName: 'Global Tech Foundation',
          grantor: 'Education Council',
        ),
        status: EntitlementStatus.active,
        categoryIds: {'development', 'data'},
        validFrom: now.subtract(const Duration(days: 30)),
        validUntil: now.add(const Duration(days: 335)),
      ),
    ];

    // 5. Admin grant recipient (perpetual global)
    _entitlementsByLearner['admin-grant-learner'] = [
      Entitlement(
        id: 'ent-adm-01',
        learnerId: 'admin-grant-learner',
        source: const AdministrativeGrantEntitlementSource(
          sourceId: 'adm-grant-01',
          grantedBy: 'admin@platform.internal',
          reason: 'Faculty Reviewer All-Access',
          ticketId: 'SEC-8821',
        ),
        status: EntitlementStatus.active,
        validFrom: now.subtract(const Duration(days: 10)),
        validUntil: null,
      ),
    ];

    // 6. Time-limited access learner
    _entitlementsByLearner['timelimited-learner'] = [
      Entitlement(
        id: 'ent-time-01',
        learnerId: 'timelimited-learner',
        source: const TimeLimitedAccessEntitlementSource(
          sourceId: 'window-weekend-01',
          windowId: 'FREE-WEEKEND-PASS',
          grantReason: 'Community Open Weekend',
        ),
        status: EntitlementStatus.active,
        validFrom: now.subtract(const Duration(hours: 12)),
        validUntil: now.add(const Duration(hours: 36)),
      ),
    ];
  }

  @override
  Future<List<Entitlement>> fetchEntitlements(String learnerId) async {
    // If unknown learner in development, provide default empty list
    final list = _entitlementsByLearner[learnerId] ?? const [];
    return List.unmodifiable(list);
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
    final entitlements = _entitlementsByLearner[learnerId] ?? const [];
    final decision = AccessEvaluator.evaluate(
      resourceType: resourceType,
      resourceId: targetId,
      effectivePolicy: effectivePolicy,
      entitlements: entitlements,
      categoryIds: categoryIds,
      courseId: courseId,
    );
    return decision.canAccess;
  }

  @override
  Future<AccessDecision> fetchAccessDecision({
    required String learnerId,
    required ResourceType resourceType,
    required String targetId,
    required AccessPolicy effectivePolicy,
    Set<String>? categoryIds,
    String? courseId,
  }) async => AccessEvaluator.evaluate(
    resourceType: resourceType,
    resourceId: targetId,
    effectivePolicy: effectivePolicy,
    entitlements: _entitlementsByLearner[learnerId] ?? const [],
    categoryIds: categoryIds,
    courseId: courseId,
  );

  /// Helper to seed or simulate purchases/grants during test or development flows.
  void grantEntitlement(Entitlement entitlement) {
    final current = _entitlementsByLearner[entitlement.learnerId] ?? [];
    _entitlementsByLearner[entitlement.learnerId] = [...current, entitlement];
  }

  /// Helper to revoke or clear entitlements for testing.
  void clearEntitlements(String learnerId) {
    _entitlementsByLearner.remove(learnerId);
  }
}
