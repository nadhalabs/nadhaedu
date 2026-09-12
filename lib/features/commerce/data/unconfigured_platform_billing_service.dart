import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';

final class UnconfiguredPlatformBillingService
    implements PlatformBillingService {
  const UnconfiguredPlatformBillingService();

  @override
  Future<void> initialize() async {}

  @override
  Future<List<PlatformProductDetails>> getStoreProducts(
    List<String> storeProductIds,
  ) async {
    return const [];
  }

  @override
  Future<PlatformPurchaseResult> purchaseProduct(
    String storeProductId, {
    String? oldStoreProductId,
    ProrationMode? prorationMode,
  }) async {
    return const PlatformPurchaseError(
      errorCode: 'billing_unconfigured',
      errorMessage:
          'Platform in-app billing is not configured in this environment.',
    );
  }

  @override
  Future<List<PaymentTransaction>> restorePurchases() async {
    return const [];
  }

  @override
  Future<void> presentCodeRedemptionSheet() async {}

  @override
  Future<void> presentManageSubscriptions() async {}

  @override
  void dispose() {}
}
