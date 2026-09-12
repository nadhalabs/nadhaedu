import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/platform_billing_service.dart';

final class FoundationPlatformBillingService implements PlatformBillingService {
  FoundationPlatformBillingService({
    this.shouldSimulateUserCancellation = false,
    this.shouldSimulateError = false,
    this.simulatedErrorMessage,
  });

  bool shouldSimulateUserCancellation;
  bool shouldSimulateError;
  String? simulatedErrorMessage;

  final List<PaymentTransaction> _simulatedPastTransactions = [];
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<List<PlatformProductDetails>> getStoreProducts(
    List<String> storeProductIds,
  ) async {
    return storeProductIds
        .map((id) {
          return PlatformProductDetails(
            storeProductId: id,
            title: 'Store Product ($id)',
            description: 'Native in-app purchase store item',
            priceCents: 1499,
            formattedPrice: '\$14.99',
            currencyCode: 'USD',
          );
        })
        .toList(growable: false);
  }

  @override
  Future<PlatformPurchaseResult> purchaseProduct(
    String storeProductId, {
    String? oldStoreProductId,
    ProrationMode? prorationMode,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (shouldSimulateUserCancellation) {
      return const PlatformPurchaseUserCancelled();
    }

    if (shouldSimulateError) {
      return PlatformPurchaseError(
        errorCode: 'payment_declined',
        errorMessage:
            simulatedErrorMessage ?? 'Simulated payment processing error.',
      );
    }

    final transaction = PaymentTransaction(
      id: 'tx_platform_${DateTime.now().millisecondsSinceEpoch}',
      provider: CommerceProvider.mock,
      providerTransactionId: storeProductId,
      receiptPayload: 'mock_receipt_payload_for_$storeProductId',
      status: PaymentTransactionStatus.success,
      timestamp: DateTime.now().toUtc(),
      amountCents: 1499,
      currencyCode: 'USD',
    );

    _simulatedPastTransactions.add(transaction);
    return PlatformPurchaseSuccess(transaction);
  }

  @override
  Future<List<PaymentTransaction>> restorePurchases() async {
    return List.unmodifiable(_simulatedPastTransactions);
  }

  @override
  Future<void> presentCodeRedemptionSheet() async {
    // Simulated native StoreKit code redemption dialog
  }

  @override
  Future<void> presentManageSubscriptions() async {
    // Simulated native App Store / Play Store subscription management screen
  }

  @override
  void dispose() {}
}
