import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/commerce/data/commerce_data_source.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/commerce_repository.dart';
import 'package:learning_platform/features/commerce/domain/coupon.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/purchase.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_source.dart';
import 'package:learning_platform/features/entitlements/domain/entitlement_status.dart';
import 'package:learning_platform/features/entitlements/domain/resource_type.dart';

final class RemoteCommerceDataSource implements CommerceDataSource {
  const RemoteCommerceDataSource(this._client);

  final ApiClient _client;

  @override
  Future<List<SubscriptionPlan>> fetchSubscriptionPlans() async {
    final json = await _get('/api/v1/commerce/plans');
    final items = _list(json, 'items');
    return items.map((x) => _parsePlan(_asMap(x))).toList(growable: false);
  }

  @override
  Future<List<CourseProduct>> fetchCourseProducts() async {
    final json = await _get('/api/v1/commerce/products/courses');
    final items = _list(json, 'items');
    return items
        .map((x) => _parseCourseProduct(_asMap(x)))
        .toList(growable: false);
  }

  @override
  Future<List<BundleProduct>> fetchBundleProducts() async {
    final json = await _get('/api/v1/commerce/products/bundles');
    final items = _list(json, 'items');
    return items
        .map((x) => _parseBundleProduct(_asMap(x)))
        .toList(growable: false);
  }

  @override
  Future<Coupon?> validateCoupon(String code, {String? productId}) async {
    final body = <String, Object?>{
      'code': code.trim(),
      ...?productId == null ? null : {'productId': productId},
    };
    final res = await _post('/api/v1/commerce/coupons/validate', body: body);
    if (res['valid'] == false) return null;
    return _parseCoupon(res);
  }

  @override
  Future<CommerceVerificationResult> verifyTransaction({
    required PaymentTransaction transaction,
    required String learnerId,
    String? idempotencyKey,
    String? couponCode,
  }) async {
    final body = <String, Object?>{
      'transactionId': transaction.id,
      'provider': transaction.provider.name,
      'providerTransactionId': transaction.providerTransactionId,
      'receiptPayload': transaction.receiptPayload,
      'amountCents': transaction.amountCents,
      'currencyCode': transaction.currencyCode,
      'learnerId': learnerId,
      ...?idempotencyKey == null ? null : {'idempotencyKey': idempotencyKey},
      ...?couponCode == null ? null : {'couponCode': couponCode},
    };

    final headers = <String, Object?>{
      ...?idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey},
    };

    final json = await _post(
      '/api/v1/commerce/transactions/verify',
      body: body,
      headers: headers,
    );

    final isSuccess = json['verified'] == true;
    final purchaseMap = json['purchase'] as Map<String, Object?>?;
    final subscriptionMap = json['subscription'] as Map<String, Object?>?;
    final entitlementsList = _list(json, 'grantedEntitlements');

    return CommerceVerificationResult(
      transaction: transaction.copyWith(
        status: isSuccess
            ? PaymentTransactionStatus.success
            : PaymentTransactionStatus.failed,
      ),
      isSuccess: isSuccess,
      purchase: purchaseMap == null ? null : _parsePurchase(purchaseMap),
      subscription: subscriptionMap == null
          ? null
          : _parseSubscription(subscriptionMap),
      grantedEntitlements: entitlementsList
          .map((e) => _parseEntitlement(_asMap(e)))
          .toList(growable: false),
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  Future<RestorePurchasesResult> restorePurchases({
    required List<PaymentTransaction> transactions,
    required String learnerId,
  }) async {
    final body = <String, Object?>{
      'learnerId': learnerId,
      'transactions': transactions
          .map(
            (t) => {
              'transactionId': t.id,
              'provider': t.provider.name,
              'providerTransactionId': t.providerTransactionId,
              'receiptPayload': t.receiptPayload,
            },
          )
          .toList(growable: false),
    };

    final json = await _post('/api/v1/commerce/restore', body: body);
    final isSuccess = json['success'] == true;
    final purchasesList = _list(json, 'restoredPurchases');
    final subscriptionMap = json['activeSubscription'] as Map<String, Object?>?;
    final entitlementsList = _list(json, 'restoredEntitlements');

    return RestorePurchasesResult(
      restoredCount: json['restoredCount'] as int? ?? 0,
      isSuccess: isSuccess,
      restoredPurchases: purchasesList
          .map((p) => _parsePurchase(_asMap(p)))
          .toList(growable: false),
      activeSubscription: subscriptionMap == null
          ? null
          : _parseSubscription(subscriptionMap),
      restoredEntitlements: entitlementsList
          .map((e) => _parseEntitlement(_asMap(e)))
          .toList(growable: false),
      message: json['message'] as String?,
    );
  }

  @override
  Future<Subscription?> fetchLearnerActiveSubscription(String learnerId) async {
    final json = await _get('/api/v1/commerce/subscriptions/active');
    final subData = json['subscription'] as Map<String, Object?>?;
    if (subData == null) return null;
    return _parseSubscription(subData);
  }

  @override
  Future<List<Purchase>> fetchLearnerPurchases(String learnerId) async {
    final json = await _get('/api/v1/commerce/purchases');
    final items = _list(json, 'items');
    return items.map((x) => _parsePurchase(_asMap(x))).toList(growable: false);
  }

  @override
  Future<Subscription> cancelSubscription({
    required String subscriptionId,
    required String learnerId,
    String? reason,
  }) async {
    final body = <String, Object?>{
      'learnerId': learnerId,
      ...?reason == null ? null : {'reason': reason},
    };
    final json = await _post(
      '/api/v1/commerce/subscriptions/${Uri.encodeComponent(subscriptionId)}/cancel',
      body: body,
    );
    return _parseSubscription(_asMap(json['subscription']));
  }

  @override
  Future<Subscription> changeSubscriptionPlan({
    required String currentSubscriptionId,
    required String newPlanId,
    required String learnerId,
    ProrationMode? prorationMode,
  }) async {
    final body = <String, Object?>{
      'learnerId': learnerId,
      'newPlanId': newPlanId,
      if (prorationMode != null) 'prorationMode': prorationMode.name,
    };
    final json = await _post(
      '/api/v1/commerce/subscriptions/${Uri.encodeComponent(currentSubscriptionId)}/change-plan',
      body: body,
    );
    return _parseSubscription(_asMap(json['subscription']));
  }

  Future<Map<String, Object?>> _get(String path) async {
    return switch (await _client.get(path)) {
      Success(value: final v) => v,
      Failure(failure: final f) => throw _mapError(f),
    };
  }

  Future<Map<String, Object?>> _post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
  }) async {
    return switch (await _client.post(path, body: body, headers: headers)) {
      Success(value: final v) => v,
      Failure(failure: final f) => throw _mapError(f),
    };
  }

  CommerceDataException _mapError(Object failure) {
    if (failure is ApiFailure) {
      return switch (failure.kind) {
        ApiErrorKind.authenticationRequired => const CommerceDataException(
          CommerceErrorKind.unauthenticated,
        ),
        ApiErrorKind.accessDenied => const CommerceDataException(
          CommerceErrorKind.forbidden,
        ),
        ApiErrorKind.notFound => const CommerceDataException(
          CommerceErrorKind.notFound,
        ),
        ApiErrorKind.conflict => const CommerceDataException(
          CommerceErrorKind.duplicateTransaction,
        ),
        ApiErrorKind.offline || ApiErrorKind.timeout =>
          const CommerceDataException(CommerceErrorKind.network),
        _ => CommerceDataException(CommerceErrorKind.unknown, failure.message),
      };
    }
    return CommerceDataException(
      CommerceErrorKind.unknown,
      'We couldn’t finish that. Please try again.',
    );
  }

  Map<String, Object?> _asMap(Object? value) {
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    return const {};
  }

  List<Object?> _list(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is List) return value;
    return const [];
  }

  SubscriptionPlan _parsePlan(Map<String, Object?> j) {
    final introMap = j['introductoryOffer'] as Map<String, Object?>?;
    return SubscriptionPlan(
      id: j['id']! as String,
      tier: SubscriptionTier.values.byName(j['tier']! as String),
      billingInterval: BillingInterval.values.byName(
        j['billingInterval']! as String,
      ),
      name: j['name']! as String,
      description: j['description']! as String,
      priceCents: j['priceCents']! as int,
      formattedPrice: j['formattedPrice']! as String,
      currencyCode: j['currencyCode']! as String,
      trialDays: j['trialDays'] as int? ?? 0,
      introductoryOffer: introMap == null
          ? null
          : IntroductoryOffer(
              id: introMap['id']! as String,
              priceCents: introMap['priceCents']! as int,
              formattedPrice: introMap['formattedPrice']! as String,
              durationDays: introMap['durationDays']! as int,
              cyclesCount: introMap['cyclesCount'] as int? ?? 1,
            ),
      benefits: (j['benefits'] as List?)?.cast<String>() ?? const [],
      isPopular: j['isPopular'] as bool? ?? false,
      isRecommended: j['isRecommended'] as bool? ?? false,
      savingsPercent: j['savingsPercent'] as int? ?? 0,
      storeProductId: j['storeProductId'] as String?,
    );
  }

  CourseProduct _parseCourseProduct(Map<String, Object?> j) {
    return CourseProduct(
      id: j['id']! as String,
      courseId: j['courseId']! as String,
      title: j['title']! as String,
      description: j['description']! as String,
      priceCents: j['priceCents']! as int,
      formattedPrice: j['formattedPrice']! as String,
      currencyCode: j['currencyCode']! as String,
      originalPriceCents: j['originalPriceCents'] as int?,
      discountPercent: j['discountPercent'] as int? ?? 0,
      features: (j['features'] as List?)?.cast<String>() ?? const [],
      storeProductId: j['storeProductId'] as String?,
    );
  }

  BundleProduct _parseBundleProduct(Map<String, Object?> j) {
    return BundleProduct(
      id: j['id']! as String,
      bundleId: j['bundleId']! as String,
      title: j['title']! as String,
      description: j['description']! as String,
      courseIds: (j['courseIds'] as List?)?.cast<String>() ?? const [],
      priceCents: j['priceCents']! as int,
      formattedPrice: j['formattedPrice']! as String,
      currencyCode: j['currencyCode']! as String,
      originalPriceCents: j['originalPriceCents'] as int?,
      discountPercent: j['discountPercent'] as int? ?? 0,
      features: (j['features'] as List?)?.cast<String>() ?? const [],
      storeProductId: j['storeProductId'] as String?,
    );
  }

  Coupon _parseCoupon(Map<String, Object?> j) {
    return Coupon(
      code: j['code']! as String,
      discountType: DiscountType.values.byName(j['discountType']! as String),
      discountValue: j['discountValue']! as int,
      validUntil: j['validUntil'] == null
          ? null
          : DateTime.parse(j['validUntil']! as String).toUtc(),
      applicableProductIds:
          (j['applicableProductIds'] as List?)?.cast<String>().toSet() ??
          const {},
      description: j['description'] as String?,
    );
  }

  Purchase _parsePurchase(Map<String, Object?> j) {
    return Purchase(
      id: j['id']! as String,
      learnerId: j['learnerId']! as String,
      productId: j['productId']! as String,
      productType: CommerceProductType.values.byName(
        j['productType']! as String,
      ),
      orderId: j['orderId']! as String,
      transactionId: j['transactionId']! as String,
      status: PurchaseStatus.values.byName(j['status']! as String),
      purchasedAt: DateTime.parse(j['purchasedAt']! as String).toUtc(),
      amountCents: j['amountCents'] as int?,
      currencyCode: j['currencyCode'] as String?,
      metadata: (j['metadata'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }

  Subscription _parseSubscription(Map<String, Object?> j) {
    final trialMap = j['trialPeriod'] as Map<String, Object?>?;
    return Subscription(
      id: j['id']! as String,
      learnerId: j['learnerId']! as String,
      planId: j['planId']! as String,
      tier: SubscriptionTier.values.byName(j['tier']! as String),
      billingInterval: BillingInterval.values.byName(
        j['billingInterval']! as String,
      ),
      status: SubscriptionStatus.values.byName(j['status']! as String),
      currentPeriodStart: DateTime.parse(
        j['currentPeriodStart']! as String,
      ).toUtc(),
      currentPeriodEnd: DateTime.parse(
        j['currentPeriodEnd']! as String,
      ).toUtc(),
      cancelAtPeriodEnd: j['cancelAtPeriodEnd'] as bool? ?? false,
      renewsAt: j['renewsAt'] == null
          ? null
          : DateTime.parse(j['renewsAt']! as String).toUtc(),
      trialPeriod: trialMap == null
          ? null
          : TrialPeriod(
              startDate: DateTime.parse(
                trialMap['startDate']! as String,
              ).toUtc(),
              endDate: DateTime.parse(trialMap['endDate']! as String).toUtc(),
              durationDays: trialMap['durationDays']! as int,
            ),
      introductoryPriceCents: j['introductoryPriceCents'] as int?,
      cancellationReason: j['cancellationReason'] as String?,
      originalTransactionId: j['originalTransactionId'] as String?,
      latestTransactionId: j['latestTransactionId'] as String?,
      metadata: (j['metadata'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }

  Entitlement _parseEntitlement(Map<String, Object?> j) {
    final metadata =
        (j['metadata'] as Map?)?.cast<String, Object?>() ?? const {};
    final id = j['id']! as String;
    final sourceMap = j['source'] as Map<String, Object?>? ?? const {};
    final sourceType = (sourceMap['type'] ?? 'subscription') as String;

    return Entitlement(
      id: id,
      learnerId: j['learnerId']! as String,
      source: _parseEntitlementSource(sourceType, id, sourceMap),
      status: EntitlementStatus.values.byName(j['status']! as String),
      targetType: j['targetType'] == null
          ? null
          : ResourceType.values.byName(j['targetType']! as String),
      targetId: j['targetId'] as String?,
      validFrom: DateTime.parse(j['validFrom']! as String).toUtc(),
      validUntil: j['validUntil'] == null
          ? null
          : DateTime.parse(j['validUntil']! as String).toUtc(),
      metadata: metadata,
    );
  }

  EntitlementSource _parseEntitlementSource(
    String type,
    String id,
    Map<String, Object?> m,
  ) {
    return switch (type) {
      'subscription' => SubscriptionEntitlementSource(
        sourceId: id,
        planId: m['planId'] as String? ?? 'plan_pro',
        tier: m['tier'] as String? ?? 'Pro',
      ),
      'individualPurchase' => IndividualPurchaseEntitlementSource(
        sourceId: id,
        orderId: m['orderId'] as String? ?? id,
        purchasedAt: DateTime.now().toUtc(),
        amountCents: m['amountCents'] as int?,
        currencyCode: m['currencyCode'] as String?,
      ),
      'bundle' => BundleEntitlementSource(
        sourceId: id,
        bundleId: m['bundleId'] as String? ?? id,
        bundleTitle: m['bundleTitle'] as String? ?? 'Bundle',
      ),
      _ => SubscriptionEntitlementSource(
        sourceId: id,
        planId: 'plan_pro',
        tier: 'Pro',
      ),
    };
  }
}
