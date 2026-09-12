import 'package:learning_platform/core/errors/app_failure.dart';
import 'package:learning_platform/core/persistence/key_value_store.dart';
import 'package:learning_platform/features/commerce/data/commerce_data_source.dart';
import 'package:learning_platform/features/commerce/domain/commerce_product.dart';
import 'package:learning_platform/features/commerce/domain/commerce_repository.dart';
import 'package:learning_platform/features/commerce/domain/coupon.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';
import 'package:learning_platform/features/commerce/domain/purchase.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

final class CommerceRepositoryImpl implements CommerceRepository {
  CommerceRepositoryImpl({
    required CommerceDataSource dataSource,
    KeyValueStore? localStore,
    required String learnerId,
  }) : _dataSource = dataSource,
       _localStore = localStore,
       _learnerId = learnerId;

  final CommerceDataSource _dataSource;
  // ignore: unused_field
  final KeyValueStore? _localStore;
  final String _learnerId;

  List<SubscriptionPlan>? _cachedPlans;
  List<CourseProduct>? _cachedCourseProducts;
  List<BundleProduct>? _cachedBundleProducts;

  @override
  Future<List<SubscriptionPlan>> getSubscriptionPlans({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedPlans != null) {
      return _cachedPlans!;
    }
    try {
      final plans = await _dataSource.fetchSubscriptionPlans();
      _cachedPlans = plans;
      return plans;
    } on CommerceDataException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<List<CourseProduct>> getCourseProducts({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedCourseProducts != null) {
      return _cachedCourseProducts!;
    }
    try {
      final products = await _dataSource.fetchCourseProducts();
      _cachedCourseProducts = products;
      return products;
    } on CommerceDataException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<List<BundleProduct>> getBundleProducts({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedBundleProducts != null) {
      return _cachedBundleProducts!;
    }
    try {
      final bundles = await _dataSource.fetchBundleProducts();
      _cachedBundleProducts = bundles;
      return bundles;
    } on CommerceDataException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<SubscriptionPlan?> getSubscriptionPlanById(String planId) async {
    final plans = await getSubscriptionPlans();
    return plans.cast<SubscriptionPlan?>().firstWhere(
      (p) => p?.id == planId,
      orElse: () => null,
    );
  }

  @override
  Future<CourseProduct?> getCourseProductById(String productId) async {
    final products = await getCourseProducts();
    return products.cast<CourseProduct?>().firstWhere(
      (p) => p?.id == productId || p?.courseId == productId,
      orElse: () => null,
    );
  }

  @override
  Future<Coupon?> validateCoupon(String code, {String? productId}) async {
    try {
      return await _dataSource.validateCoupon(code, productId: productId);
    } on CommerceDataException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<CommerceVerificationResult> verifyAndProcessTransaction(
    PaymentTransaction transaction, {
    String? idempotencyKey,
    String? couponCode,
    String? learnerId,
  }) async {
    try {
      return await _dataSource.verifyTransaction(
        transaction: transaction,
        learnerId: learnerId ?? _learnerId,
        idempotencyKey: idempotencyKey,
        couponCode: couponCode,
      );
    } on CommerceDataException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<RestorePurchasesResult> restoreAndReconcilePurchases(
    List<PaymentTransaction> transactions, {
    required String learnerId,
  }) async {
    try {
      return await _dataSource.restorePurchases(
        transactions: transactions,
        learnerId: learnerId,
      );
    } on CommerceDataException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<Subscription?> getLearnerActiveSubscription(String learnerId) async {
    try {
      return await _dataSource.fetchLearnerActiveSubscription(learnerId);
    } on CommerceDataException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<List<Purchase>> getLearnerPurchases(String learnerId) async {
    try {
      return await _dataSource.fetchLearnerPurchases(learnerId);
    } on CommerceDataException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<Subscription> cancelSubscription(
    String subscriptionId, {
    String? reason,
  }) async {
    try {
      return await _dataSource.cancelSubscription(
        subscriptionId: subscriptionId,
        learnerId: _learnerId,
        reason: reason,
      );
    } on CommerceDataException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<Subscription> changeSubscriptionPlan({
    required String currentSubscriptionId,
    required String newPlanId,
    ProrationMode? prorationMode,
  }) async {
    try {
      return await _dataSource.changeSubscriptionPlan(
        currentSubscriptionId: currentSubscriptionId,
        newPlanId: newPlanId,
        learnerId: _learnerId,
        prorationMode: prorationMode,
      );
    } on CommerceDataException catch (e) {
      throw _mapException(e);
    }
  }

  AppFailure _mapException(CommerceDataException e) {
    return switch (e.kind) {
      CommerceErrorKind.unauthenticated => const AuthFailure(
        code: 'unauthenticated',
        message: 'Authentication required for commerce operations.',
      ),
      CommerceErrorKind.forbidden => const AuthFailure(
        code: 'forbidden',
        message: 'Access forbidden.',
      ),
      CommerceErrorKind.notFound => const NotFoundFailure(
        code: 'not_found',
        message: 'Resource not found.',
      ),
      CommerceErrorKind.duplicateTransaction => const ValidationFailure(
        code: 'duplicate_transaction',
        message: 'This transaction was already processed.',
      ),
      CommerceErrorKind.invalidTransaction => const ValidationFailure(
        code: 'invalid_transaction',
        message: 'Invalid payment transaction payload.',
      ),
      CommerceErrorKind.invalidCoupon => const ValidationFailure(
        code: 'invalid_coupon',
        message: 'Invalid or expired promo code.',
      ),
      CommerceErrorKind.paymentFailed => const ValidationFailure(
        code: 'payment_failed',
        message: 'Payment processing failed.',
      ),
      CommerceErrorKind.network => const NetworkFailure(
        code: 'network_error',
        message: 'Network connection issue during commerce operation.',
      ),
      CommerceErrorKind.unconfigured => const UnexpectedFailure(
        code: 'commerce_unconfigured',
        message: 'Commerce system is unconfigured in this environment.',
      ),
      CommerceErrorKind.unknown => UnexpectedFailure(
        code: 'commerce_error',
        message: e.message.isEmpty ? 'Commerce operation failed.' : e.message,
      ),
    };
  }
}
