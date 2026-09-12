import 'package:learning_platform/features/commerce/data/commerce_data_source.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/commerce_repository.dart';
import 'package:learning_platform/features/commerce/domain/coupon.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/purchase.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';
import 'package:learning_platform/features/entitlements/data/foundation_entitlement_data_source.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_source.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_status.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

final class FoundationCommerceDataSource implements CommerceDataSource {
  FoundationCommerceDataSource({
    FoundationEntitlementDataSource? entitlementDataSource,
  }) : _entitlementDataSource = entitlementDataSource {
    _initSeedData();
  }

  final FoundationEntitlementDataSource? _entitlementDataSource;

  final List<SubscriptionPlan> _plans = [];
  final List<CourseProduct> _courseProducts = [];
  final List<BundleProduct> _bundleProducts = [];
  final Map<String, Coupon> _coupons = {};
  final Map<String, List<Purchase>> _purchasesByLearner = {};
  final Map<String, Subscription> _subscriptionsByLearner = {};

  void _initSeedData() {
    _plans.addAll([
      const SubscriptionPlan(
        id: 'plan_pro_monthly',
        tier: SubscriptionTier.pro,
        billingInterval: BillingInterval.monthly,
        name: 'Pro Monthly',
        description:
            'Unlimited access to all courses, projects, and certificates.',
        priceCents: 1499,
        formattedPrice: '\$14.99',
        currencyCode: 'USD',
        trialDays: 7,
        benefits: [
          'Full access to all 500+ courses',
          'Official verified certificates',
          'Interactive coding exercises & quizzes',
          'Offline downloads on mobile',
          'Direct instructor Q&A',
        ],
        storeProductId: 'com.learningplatform.subscription.pro.monthly',
      ),
      const SubscriptionPlan(
        id: 'plan_pro_annual',
        tier: SubscriptionTier.pro,
        billingInterval: BillingInterval.annual,
        name: 'Pro Annual',
        description:
            'Best value for committed learners. Save 33% compared to monthly.',
        priceCents: 11999,
        formattedPrice: '\$119.99',
        currencyCode: 'USD',
        trialDays: 14,
        savingsPercent: 33,
        isPopular: true,
        isRecommended: true,
        benefits: [
          'All Pro Monthly features',
          '14-day free trial included',
          '33% annual discount',
          'Early access to new course releases',
          'Priority support response',
        ],
        storeProductId: 'com.learningplatform.subscription.pro.annual',
      ),
      const SubscriptionPlan(
        id: 'plan_student_monthly',
        tier: SubscriptionTier.student,
        billingInterval: BillingInterval.monthly,
        name: 'Student Pro',
        description:
            'Discounted plan for verified students and academic learners.',
        priceCents: 799,
        formattedPrice: '\$7.99',
        currencyCode: 'USD',
        trialDays: 7,
        savingsPercent: 46,
        benefits: [
          'Full Pro access during academic terms',
          'Verified student certificate credentials',
          'Student study community access',
        ],
        storeProductId: 'com.learningplatform.subscription.student.monthly',
      ),
      const SubscriptionPlan(
        id: 'plan_family_annual',
        tier: SubscriptionTier.family,
        billingInterval: BillingInterval.annual,
        name: 'Family Plan',
        description:
            'One plan for up to 5 family members with individual profiles.',
        priceCents: 19999,
        formattedPrice: '\$199.99',
        currencyCode: 'USD',
        trialDays: 14,
        savingsPercent: 40,
        benefits: [
          'Up to 5 independent learner accounts',
          'Family progress dashboard',
          'All Pro tier features for every member',
        ],
        storeProductId: 'com.learningplatform.subscription.family.annual',
      ),
      const SubscriptionPlan(
        id: 'plan_institution_annual',
        tier: SubscriptionTier.institution,
        billingInterval: BillingInterval.annual,
        name: 'Institution & Enterprise',
        description:
            'Enterprise grade learning with centralized team analytics.',
        priceCents: 99900,
        formattedPrice: '\$999.00',
        currencyCode: 'USD',
        benefits: [
          'Enterprise organization license',
          'Custom learning paths and LMS integration',
          'Dedicated account manager & SLA',
        ],
        storeProductId: 'com.learningplatform.subscription.institution.annual',
      ),
    ]);

    _courseProducts.addAll([
      const CourseProduct(
        id: 'prod_course_1',
        courseId: 'course-1',
        title: 'Modern Flutter Architecture Masterclass',
        description:
            'Master clean architecture, Riverpod, state orchestration, and testing.',
        priceCents: 4900,
        formattedPrice: '\$49.00',
        currencyCode: 'USD',
        originalPriceCents: 5900,
        discountPercent: 17,
        features: [
          'Lifetime access to all lessons and updates',
          'Downloadable code repositories & slides',
          'Course completion certificate',
        ],
        storeProductId: 'com.learningplatform.course.flutter_arch',
      ),
      const CourseProduct(
        id: 'prod_course_2',
        courseId: 'course-2',
        title: 'Dart Deep Dive: Concurrency & FFI',
        description:
            'Advanced Dart patterns, isolates, memory management, and C interop.',
        priceCents: 3900,
        formattedPrice: '\$39.00',
        currencyCode: 'USD',
        features: [
          'Lifetime access to lessons',
          'FFI bindings generator examples',
          'Certificate of completion',
        ],
        storeProductId: 'com.learningplatform.course.dart_deep_dive',
      ),
      const CourseProduct(
        id: 'prod_course_3',
        courseId: 'course-3',
        title: 'Full-Stack Cloud & Backend Development',
        description:
            'Build production backend services, APIs, and scalable infrastructure.',
        priceCents: 5900,
        formattedPrice: '\$59.00',
        currencyCode: 'USD',
        features: [
          'Lifetime course access',
          'Cloud deployment sandbox access',
          'Certificate of completion',
        ],
        storeProductId: 'com.learningplatform.course.cloud_backend',
      ),
    ]);

    _bundleProducts.addAll([
      const BundleProduct(
        id: 'prod_bundle_mobile_dev',
        bundleId: 'bundle-mobile-dev',
        title: 'Complete Mobile Architecture Bundle',
        description:
            'Get both Flutter Architecture and Dart Deep Dive at a special bundle discount.',
        courseIds: ['course-1', 'course-2'],
        priceCents: 6900,
        formattedPrice: '\$69.00',
        currencyCode: 'USD',
        originalPriceCents: 8800,
        discountPercent: 21,
        features: [
          'Includes 2 comprehensive courses',
          'Lifetime access to all updates',
          '2 Official course certificates',
        ],
        storeProductId: 'com.learningplatform.bundle.mobile_arch',
      ),
    ]);

    _coupons['SAVE20'] = Coupon(
      code: 'SAVE20',
      discountType: DiscountType.percentage,
      discountValue: 20,
      validUntil: DateTime.now().toUtc().add(const Duration(days: 30)),
      description: '20% off any subscription or course',
    );
    _coupons['PRO10'] = Coupon(
      code: 'PRO10',
      discountType: DiscountType.fixedAmount,
      discountValue: 1000,
      validUntil: DateTime.now().toUtc().add(const Duration(days: 60)),
      description: '\$10 off your order',
    );
    _coupons['WELCOME50'] = Coupon(
      code: 'WELCOME50',
      discountType: DiscountType.percentage,
      discountValue: 50,
      validUntil: DateTime.now().toUtc().add(const Duration(days: 14)),
      description: '50% off welcome promotion',
    );
  }

  @override
  Future<List<SubscriptionPlan>> fetchSubscriptionPlans() async {
    return List.unmodifiable(_plans);
  }

  @override
  Future<List<CourseProduct>> fetchCourseProducts() async {
    return List.unmodifiable(_courseProducts);
  }

  @override
  Future<List<BundleProduct>> fetchBundleProducts() async {
    return List.unmodifiable(_bundleProducts);
  }

  @override
  Future<Coupon?> validateCoupon(String code, {String? productId}) async {
    final coupon = _coupons[code.trim().toUpperCase()];
    if (coupon == null) return null;
    if (!coupon.isUsableAt(DateTime.now().toUtc(), productId: productId)) {
      return null;
    }
    return coupon;
  }

  @override
  Future<CommerceVerificationResult> verifyTransaction({
    required PaymentTransaction transaction,
    required String learnerId,
    String? idempotencyKey,
    String? couponCode,
  }) async {
    if (!transaction.isSuccessful) {
      return CommerceVerificationResult(
        transaction: transaction,
        isSuccess: false,
        errorMessage: transaction.errorMessage ?? 'Payment transaction failed.',
      );
    }

    final now = DateTime.now().toUtc();
    final grantedEntitlements = <Entitlement>[];

    // Determine if this transaction corresponds to a subscription or a course product
    final plan = _plans.cast<SubscriptionPlan?>().firstWhere(
      (p) =>
          p?.storeProductId == transaction.providerTransactionId ||
          p?.id == transaction.providerTransactionId,
      orElse: () => null,
    );

    if (plan != null) {
      final periodEnd = plan.billingInterval == BillingInterval.annual
          ? now.add(const Duration(days: 365))
          : now.add(const Duration(days: 30));

      final sub = Subscription(
        id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
        learnerId: learnerId,
        planId: plan.id,
        tier: plan.tier,
        billingInterval: plan.billingInterval,
        status: plan.hasTrial
            ? SubscriptionStatus.trialing
            : SubscriptionStatus.active,
        currentPeriodStart: now,
        currentPeriodEnd: periodEnd,
        renewsAt: periodEnd,
        trialPeriod: plan.hasTrial
            ? TrialPeriod(
                startDate: now,
                endDate: now.add(Duration(days: plan.trialDays)),
                durationDays: plan.trialDays,
              )
            : null,
        originalTransactionId: transaction.id,
        latestTransactionId: transaction.id,
      );
      _subscriptionsByLearner[learnerId] = sub;

      final entitlement = Entitlement(
        id: 'ent_${sub.id}',
        learnerId: learnerId,
        source: SubscriptionEntitlementSource(
          sourceId: sub.id,
          planId: plan.id,
          tier: plan.tier.displayName,
          renewsAt: sub.renewsAt,
          autoRenewing: true,
        ),
        status: EntitlementStatus.active,
        validFrom: now,
        validUntil: periodEnd,
      );
      grantedEntitlements.add(entitlement);
      _entitlementDataSource?.grantEntitlement(entitlement);

      return CommerceVerificationResult(
        transaction: transaction,
        isSuccess: true,
        subscription: sub,
        grantedEntitlements: grantedEntitlements,
      );
    }

    // Check course product
    final courseProduct = _courseProducts.cast<CourseProduct?>().firstWhere(
      (c) =>
          c?.storeProductId == transaction.providerTransactionId ||
          c?.id == transaction.providerTransactionId ||
          c?.courseId == transaction.providerTransactionId,
      orElse: () => null,
    );

    if (courseProduct != null) {
      final purchase = Purchase(
        id: 'pur_${DateTime.now().millisecondsSinceEpoch}',
        learnerId: learnerId,
        productId: courseProduct.id,
        productType: CommerceProductType.course,
        orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
        transactionId: transaction.id,
        status: PurchaseStatus.completed,
        purchasedAt: now,
        amountCents: courseProduct.priceCents,
        currencyCode: courseProduct.currencyCode,
      );
      _purchasesByLearner.putIfAbsent(learnerId, () => []).add(purchase);

      final entitlement = Entitlement(
        id: 'ent_${purchase.id}',
        learnerId: learnerId,
        source: IndividualPurchaseEntitlementSource(
          sourceId: purchase.id,
          orderId: purchase.orderId,
          purchasedAt: now,
          amountCents: purchase.amountCents,
          currencyCode: purchase.currencyCode,
        ),
        status: EntitlementStatus.active,
        targetType: ResourceType.course,
        targetId: courseProduct.courseId,
        validFrom: now,
        validUntil: null, // perpetual
      );
      grantedEntitlements.add(entitlement);
      _entitlementDataSource?.grantEntitlement(entitlement);

      return CommerceVerificationResult(
        transaction: transaction,
        isSuccess: true,
        purchase: purchase,
        grantedEntitlements: grantedEntitlements,
      );
    }

    // Check bundle product
    final bundleProduct = _bundleProducts.cast<BundleProduct?>().firstWhere(
      (b) =>
          b?.storeProductId == transaction.providerTransactionId ||
          b?.id == transaction.providerTransactionId ||
          b?.bundleId == transaction.providerTransactionId,
      orElse: () => null,
    );

    if (bundleProduct != null) {
      final purchase = Purchase(
        id: 'pur_${DateTime.now().millisecondsSinceEpoch}',
        learnerId: learnerId,
        productId: bundleProduct.id,
        productType: CommerceProductType.bundle,
        orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
        transactionId: transaction.id,
        status: PurchaseStatus.completed,
        purchasedAt: now,
        amountCents: bundleProduct.priceCents,
        currencyCode: bundleProduct.currencyCode,
      );
      _purchasesByLearner.putIfAbsent(learnerId, () => []).add(purchase);

      final entitlement = Entitlement(
        id: 'ent_${purchase.id}',
        learnerId: learnerId,
        source: BundleEntitlementSource(
          sourceId: purchase.id,
          bundleId: bundleProduct.bundleId,
          bundleTitle: bundleProduct.title,
        ),
        status: EntitlementStatus.active,
        validFrom: now,
        validUntil: null, // perpetual
      );
      grantedEntitlements.add(entitlement);
      _entitlementDataSource?.grantEntitlement(entitlement);

      return CommerceVerificationResult(
        transaction: transaction,
        isSuccess: true,
        purchase: purchase,
        grantedEntitlements: grantedEntitlements,
      );
    }

    // Fallback default subscription
    final defaultSub = Subscription(
      id: 'sub_default_${DateTime.now().millisecondsSinceEpoch}',
      learnerId: learnerId,
      planId: 'plan_pro_monthly',
      tier: SubscriptionTier.pro,
      billingInterval: BillingInterval.monthly,
      status: SubscriptionStatus.active,
      currentPeriodStart: now,
      currentPeriodEnd: now.add(const Duration(days: 30)),
      renewsAt: now.add(const Duration(days: 30)),
      originalTransactionId: transaction.id,
      latestTransactionId: transaction.id,
    );
    _subscriptionsByLearner[learnerId] = defaultSub;

    final defaultEntitlement = Entitlement(
      id: 'ent_${defaultSub.id}',
      learnerId: learnerId,
      source: SubscriptionEntitlementSource(
        sourceId: defaultSub.id,
        planId: defaultSub.planId,
        tier: 'Pro',
      ),
      status: EntitlementStatus.active,
      validFrom: now,
      validUntil: defaultSub.currentPeriodEnd,
    );
    grantedEntitlements.add(defaultEntitlement);
    _entitlementDataSource?.grantEntitlement(defaultEntitlement);

    return CommerceVerificationResult(
      transaction: transaction,
      isSuccess: true,
      subscription: defaultSub,
      grantedEntitlements: grantedEntitlements,
    );
  }

  @override
  Future<RestorePurchasesResult> restorePurchases({
    required List<PaymentTransaction> transactions,
    required String learnerId,
  }) async {
    final purchases = _purchasesByLearner[learnerId] ?? [];
    final activeSub = _subscriptionsByLearner[learnerId];
    final entitlements = <Entitlement>[];

    for (final p in purchases) {
      entitlements.add(
        Entitlement(
          id: 'ent_restored_${p.id}',
          learnerId: learnerId,
          source: IndividualPurchaseEntitlementSource(
            sourceId: p.id,
            orderId: p.orderId,
            purchasedAt: p.purchasedAt,
          ),
          status: EntitlementStatus.active,
          validFrom: p.purchasedAt,
        ),
      );
    }

    if (activeSub != null && activeSub.isUsable) {
      entitlements.add(
        Entitlement(
          id: 'ent_restored_${activeSub.id}',
          learnerId: learnerId,
          source: SubscriptionEntitlementSource(
            sourceId: activeSub.id,
            planId: activeSub.planId,
            tier: activeSub.tier.displayName,
          ),
          status: EntitlementStatus.active,
          validFrom: activeSub.currentPeriodStart,
          validUntil: activeSub.currentPeriodEnd,
        ),
      );
    }

    return RestorePurchasesResult(
      restoredCount: purchases.length + (activeSub != null ? 1 : 0),
      isSuccess: true,
      restoredPurchases: purchases,
      activeSubscription: activeSub,
      restoredEntitlements: entitlements,
      message: 'Successfully restored and reconciled previous purchases.',
    );
  }

  @override
  Future<Subscription?> fetchLearnerActiveSubscription(String learnerId) async {
    return _subscriptionsByLearner[learnerId];
  }

  @override
  Future<List<Purchase>> fetchLearnerPurchases(String learnerId) async {
    return List.unmodifiable(_purchasesByLearner[learnerId] ?? const []);
  }

  @override
  Future<Subscription> cancelSubscription({
    required String subscriptionId,
    required String learnerId,
    String? reason,
  }) async {
    final existing = _subscriptionsByLearner[learnerId];
    if (existing == null) {
      throw const CommerceDataException(
        CommerceErrorKind.notFound,
        'No active subscription found.',
      );
    }
    final updated = existing.copyWith(
      status: SubscriptionStatus.cancelled,
      cancelAtPeriodEnd: true,
      cancellationReason: reason ?? 'Learner requested cancellation',
    );
    _subscriptionsByLearner[learnerId] = updated;
    return updated;
  }

  @override
  Future<Subscription> changeSubscriptionPlan({
    required String currentSubscriptionId,
    required String newPlanId,
    required String learnerId,
    ProrationMode? prorationMode,
  }) async {
    final existing = _subscriptionsByLearner[learnerId];
    if (existing == null) {
      throw const CommerceDataException(
        CommerceErrorKind.notFound,
        'No active subscription found.',
      );
    }
    final newPlan = _plans.firstWhere(
      (p) => p.id == newPlanId,
      orElse: () => throw const CommerceDataException(
        CommerceErrorKind.notFound,
        'Target subscription plan not found.',
      ),
    );

    final now = DateTime.now().toUtc();
    final periodEnd = newPlan.billingInterval == BillingInterval.annual
        ? now.add(const Duration(days: 365))
        : now.add(const Duration(days: 30));

    final updated = existing.copyWith(
      planId: newPlan.id,
      tier: newPlan.tier,
      billingInterval: newPlan.billingInterval,
      status: SubscriptionStatus.active,
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      renewsAt: periodEnd,
      cancelAtPeriodEnd: false,
    );
    _subscriptionsByLearner[learnerId] = updated;
    return updated;
  }
}
