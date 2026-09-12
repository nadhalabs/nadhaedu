import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_evaluator.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';
import 'package:learning_platform/features/entitlements/domain/access_reason.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_source.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_status.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

void main() {
  final referenceTime = DateTime.utc(2026, 8, 31, 12, 0);

  group('AccessEvaluator', () {
    test('grants free access when effective policy is free', () {
      final decision = AccessEvaluator.evaluate(
        resourceType: ResourceType.course,
        resourceId: 'course-1',
        effectivePolicy: const AccessPolicy.free(),
        entitlements: const [],
        at: referenceTime,
      );

      expect(decision.canAccess, isTrue);
      expect(decision.state, equals(AccessState.free));
      expect(decision.reason, equals(AccessReason.freeContent));
    });

    test('grants preview access when effective policy is preview', () {
      final decision = AccessEvaluator.evaluate(
        resourceType: ResourceType.lesson,
        resourceId: 'lesson-1-1',
        effectivePolicy: const AccessPolicy.preview(),
        entitlements: const [],
        at: referenceTime,
      );

      expect(decision.canAccess, isTrue);
      expect(decision.state, equals(AccessState.preview));
      expect(decision.reason, equals(AccessReason.previewAccess));
    });

    test('locks premium content when learner has no entitlements', () {
      final decision = AccessEvaluator.evaluate(
        resourceType: ResourceType.course,
        resourceId: 'course-premium',
        effectivePolicy: const AccessPolicy.premium(),
        entitlements: const [],
        at: referenceTime,
      );

      expect(decision.canAccess, isFalse);
      expect(decision.state, equals(AccessState.locked));
      expect(decision.reason, equals(AccessReason.locked));
    });

    test('returns unavailable before considering entitlements', () {
      final decision = AccessEvaluator.evaluate(
        resourceType: ResourceType.resource,
        resourceId: 'retired-resource',
        effectivePolicy: const AccessPolicy.unavailable(),
        entitlements: const [],
        at: referenceTime,
      );

      expect(decision.canAccess, isFalse);
      expect(decision.state, AccessState.unavailable);
      expect(decision.reason, AccessReason.unavailable);
    });

    test('enforces subscription tier constraints', () {
      final basic = Entitlement(
        id: 'basic-subscription',
        learnerId: 'user-1',
        source: const SubscriptionEntitlementSource(
          sourceId: 'basic-source',
          planId: 'basic-monthly',
          tier: 'Basic',
        ),
        status: EntitlementStatus.active,
        validFrom: referenceTime.subtract(const Duration(days: 1)),
      );

      final decision = AccessEvaluator.evaluate(
        resourceType: ResourceType.course,
        resourceId: 'advanced-course',
        effectivePolicy: const AccessPolicy.premium(requiredTier: 'Pro'),
        entitlements: [basic],
        at: referenceTime,
      );

      expect(decision.canAccess, isFalse);
    });

    test('enforces bundle identity constraints', () {
      final unrelatedBundle = Entitlement(
        id: 'bundle-entitlement',
        learnerId: 'user-1',
        source: const BundleEntitlementSource(
          sourceId: 'bundle-source',
          bundleId: 'bundle-design',
          bundleTitle: 'Design Bundle',
        ),
        status: EntitlementStatus.active,
        validFrom: referenceTime.subtract(const Duration(days: 1)),
      );

      final decision = AccessEvaluator.evaluate(
        resourceType: ResourceType.course,
        resourceId: 'course-ai',
        effectivePolicy: const AccessPolicy.premium(
          requiredBundleId: 'bundle-ai',
        ),
        entitlements: [unrelatedBundle],
        at: referenceTime,
      );

      expect(decision.canAccess, isFalse);
    });

    test('grants access via active subscription', () {
      final sub = Entitlement(
        id: 'sub-1',
        learnerId: 'user-1',
        source: SubscriptionEntitlementSource(
          sourceId: 'sub-src-1',
          planId: 'pro_annual',
          tier: 'Pro',
          renewsAt: referenceTime.add(const Duration(days: 100)),
        ),
        status: EntitlementStatus.active,
        validFrom: referenceTime.subtract(const Duration(days: 30)),
        validUntil: referenceTime.add(const Duration(days: 100)),
      );

      final decision = AccessEvaluator.evaluate(
        resourceType: ResourceType.course,
        resourceId: 'course-any',
        effectivePolicy: const AccessPolicy.premium(),
        entitlements: [sub],
        at: referenceTime,
      );

      expect(decision.canAccess, isTrue);
      expect(decision.state, equals(AccessState.subscribed));
      expect(decision.reason, equals(AccessReason.activeSubscription));
      expect(decision.grantingEntitlement?.id, equals('sub-1'));
    });

    test(
      'grants access via individual course purchase covering course and child lessons',
      () {
        final purchase = Entitlement(
          id: 'pur-1',
          learnerId: 'user-1',
          source: IndividualPurchaseEntitlementSource(
            sourceId: 'ord-1',
            orderId: 'ORD-100',
            purchasedAt: referenceTime.subtract(const Duration(days: 10)),
          ),
          status: EntitlementStatus.active,
          targetType: ResourceType.course,
          targetId: 'course-10',
          validFrom: referenceTime.subtract(const Duration(days: 10)),
          validUntil: null,
        );

        // Course-level access
        final courseDecision = AccessEvaluator.evaluate(
          resourceType: ResourceType.course,
          resourceId: 'course-10',
          effectivePolicy: const AccessPolicy.premium(),
          entitlements: [purchase],
          at: referenceTime,
        );
        expect(courseDecision.canAccess, isTrue);
        expect(courseDecision.state, equals(AccessState.purchased));
        expect(courseDecision.reason, equals(AccessReason.individualPurchase));

        // Child lesson access within the purchased course
        final lessonDecision = AccessEvaluator.evaluate(
          resourceType: ResourceType.lesson,
          resourceId: 'lesson-10-4',
          courseId: 'course-10',
          effectivePolicy: const AccessPolicy.premium(),
          entitlements: [purchase],
          at: referenceTime,
        );
        expect(lessonDecision.canAccess, isTrue);
        expect(lessonDecision.state, equals(AccessState.purchased));

        // Different course should remain locked
        final otherCourseDecision = AccessEvaluator.evaluate(
          resourceType: ResourceType.course,
          resourceId: 'course-99',
          effectivePolicy: const AccessPolicy.premium(),
          entitlements: [purchase],
          at: referenceTime,
        );
        expect(otherCourseDecision.canAccess, isFalse);
      },
    );

    test('grants access via bundle inclusion', () {
      final bundle = Entitlement(
        id: 'bun-1',
        learnerId: 'user-1',
        source: const BundleEntitlementSource(
          sourceId: 'bun-src-1',
          bundleId: 'bundle-ai-mastery',
          bundleTitle: 'AI Mastery Suite',
        ),
        status: EntitlementStatus.active,
        targetId: 'course-ai-1',
        validFrom: DateTime.utc(2026, 1, 1),
      );

      final decision = AccessEvaluator.evaluate(
        resourceType: ResourceType.course,
        resourceId: 'course-ai-1',
        effectivePolicy: const AccessPolicy.premium(),
        entitlements: [bundle],
        at: referenceTime,
      );

      expect(decision.canAccess, isTrue);
      expect(decision.state, equals(AccessState.included));
      expect(decision.reason, equals(AccessReason.bundleInclusion));
    });

    test(
      'grants access via active trial and reports trialExpired after expiry',
      () {
        final activeTrial = Entitlement(
          id: 'tri-1',
          learnerId: 'user-1',
          source: const TrialEntitlementSource(
            sourceId: 'trial-src-1',
            trialDays: 14,
          ),
          status: EntitlementStatus.active,
          validFrom: referenceTime.subtract(const Duration(days: 5)),
          validUntil: referenceTime.add(const Duration(days: 9)),
        );

        final activeDecision = AccessEvaluator.evaluate(
          resourceType: ResourceType.course,
          resourceId: 'course-premium',
          effectivePolicy: const AccessPolicy.premium(),
          entitlements: [activeTrial],
          at: referenceTime,
        );
        expect(activeDecision.canAccess, isTrue);
        expect(activeDecision.reason, equals(AccessReason.activeTrial));

        // After trial expiration
        final expiredTrial = Entitlement(
          id: 'tri-1',
          learnerId: 'user-1',
          source: const TrialEntitlementSource(
            sourceId: 'trial-src-1',
            trialDays: 14,
          ),
          status: EntitlementStatus.expired,
          validFrom: referenceTime.subtract(const Duration(days: 20)),
          validUntil: referenceTime.subtract(const Duration(days: 6)),
        );

        final expiredDecision = AccessEvaluator.evaluate(
          resourceType: ResourceType.course,
          resourceId: 'course-premium',
          effectivePolicy: const AccessPolicy.premium(),
          entitlements: [expiredTrial],
          at: referenceTime,
        );
        expect(expiredDecision.canAccess, isFalse);
        expect(expiredDecision.state, equals(AccessState.expired));
        expect(expiredDecision.reason, equals(AccessReason.trialExpired));
      },
    );

    test('reports subscriptionExpired when previous subscription ended', () {
      final expiredSub = Entitlement(
        id: 'sub-exp',
        learnerId: 'user-1',
        source: const SubscriptionEntitlementSource(
          sourceId: 'sub-old',
          planId: 'monthly',
          tier: 'Pro',
        ),
        status: EntitlementStatus.expired,
        validFrom: referenceTime.subtract(const Duration(days: 60)),
        validUntil: referenceTime.subtract(const Duration(days: 2)),
      );

      final decision = AccessEvaluator.evaluate(
        resourceType: ResourceType.course,
        resourceId: 'course-premium',
        effectivePolicy: const AccessPolicy.premium(),
        entitlements: [expiredSub],
        at: referenceTime,
      );

      expect(decision.canAccess, isFalse);
      expect(decision.state, equals(AccessState.expired));
      expect(decision.reason, equals(AccessReason.subscriptionExpired));
    });

    test(
      'grants category-scoped scholarship access to matching category courses only',
      () {
        final scholarship = Entitlement(
          id: 'sch-1',
          learnerId: 'user-1',
          source: const ScholarshipEntitlementSource(
            sourceId: 'sch-org-1',
            scholarshipId: 'SCH-TECH',
            organizationName: 'Global Foundation',
          ),
          status: EntitlementStatus.active,
          categoryIds: {'development', 'data'},
          validFrom: referenceTime.subtract(const Duration(days: 10)),
          validUntil: referenceTime.add(const Duration(days: 100)),
        );

        // Course with development category
        final matchingDecision = AccessEvaluator.evaluate(
          resourceType: ResourceType.course,
          resourceId: 'course-dev',
          effectivePolicy: const AccessPolicy.premium(),
          categoryIds: {'development'},
          entitlements: [scholarship],
          at: referenceTime,
        );
        expect(matchingDecision.canAccess, isTrue);
        expect(matchingDecision.state, equals(AccessState.included));
        expect(matchingDecision.reason, equals(AccessReason.scholarshipGrant));

        // Course with unrelated category
        final nonMatchingDecision = AccessEvaluator.evaluate(
          resourceType: ResourceType.course,
          resourceId: 'course-wellbeing',
          effectivePolicy: const AccessPolicy.premium(),
          categoryIds: {'wellbeing'},
          entitlements: [scholarship],
          at: referenceTime,
        );
        expect(nonMatchingDecision.canAccess, isFalse);
        expect(nonMatchingDecision.state, equals(AccessState.locked));
      },
    );

    test(
      'resolves multiple simultaneous entitlement sources by strict precedence order',
      () {
        final sub = Entitlement(
          id: 'ent-sub',
          learnerId: 'user-1',
          source: const SubscriptionEntitlementSource(
            sourceId: 'src-sub',
            planId: 'plan_pro',
            tier: 'Pro',
          ),
          status: EntitlementStatus.active,
          validFrom: referenceTime.subtract(const Duration(days: 20)),
        );

        final purchase = Entitlement(
          id: 'ent-purchase',
          learnerId: 'user-1',
          source: IndividualPurchaseEntitlementSource(
            sourceId: 'src-ord',
            orderId: 'ORD-1',
            purchasedAt: referenceTime.subtract(const Duration(days: 15)),
          ),
          status: EntitlementStatus.active,
          targetId: 'course-1',
          validFrom: referenceTime.subtract(const Duration(days: 15)),
        );

        final adminGrant = Entitlement(
          id: 'ent-admin',
          learnerId: 'user-1',
          source: const AdministrativeGrantEntitlementSource(
            sourceId: 'src-adm',
            grantedBy: 'admin',
            reason: 'Review',
          ),
          status: EntitlementStatus.active,
          validFrom: referenceTime.subtract(const Duration(days: 5)),
        );

        // When user has Subscription + Purchase: Purchase has higher precedence than Subscription
        final decision1 = AccessEvaluator.evaluate(
          resourceType: ResourceType.course,
          resourceId: 'course-1',
          effectivePolicy: const AccessPolicy.premium(),
          entitlements: [sub, purchase],
          at: referenceTime,
        );
        expect(decision1.reason, equals(AccessReason.individualPurchase));
        expect(decision1.grantingEntitlement?.id, equals('ent-purchase'));

        // When user has Admin Grant + Purchase + Subscription: Admin Grant has highest precedence
        final decision2 = AccessEvaluator.evaluate(
          resourceType: ResourceType.course,
          resourceId: 'course-1',
          effectivePolicy: const AccessPolicy.premium(),
          entitlements: [sub, purchase, adminGrant],
          at: referenceTime,
        );
        expect(decision2.reason, equals(AccessReason.administrativeGrant));
        expect(decision2.grantingEntitlement?.id, equals('ent-admin'));
      },
    );

    test('preserves isStale flag for cached offline evaluations', () {
      final decision = AccessEvaluator.evaluate(
        resourceType: ResourceType.course,
        resourceId: 'course-1',
        effectivePolicy: const AccessPolicy.free(),
        entitlements: const [],
        isStale: true,
        at: referenceTime,
      );

      expect(decision.isStale, isTrue);
      expect(decision.canAccess, isTrue);
    });
  });
}
