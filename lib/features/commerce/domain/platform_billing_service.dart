import 'package:flutter/foundation.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';

enum ProrationMode {
  immediateWithTimeProration,
  immediateAndChargeProratedPrice,
  immediateWithoutProration,
  deferred;

  String get displayName => switch (this) {
    ProrationMode.immediateWithTimeProration =>
      'Immediate with remaining credit applied',
    ProrationMode.immediateAndChargeProratedPrice =>
      'Immediate with prorated price charge',
    ProrationMode.immediateWithoutProration =>
      'Immediate without billing adjustment',
    ProrationMode.deferred => 'Effective on next billing date',
  };
}

@immutable
final class PlatformProductDetails {
  const PlatformProductDetails({
    required this.storeProductId,
    required this.title,
    required this.description,
    required this.priceCents,
    required this.formattedPrice,
    required this.currencyCode,
  });

  final String storeProductId;
  final String title;
  final String description;
  final int priceCents;
  final String formattedPrice;
  final String currencyCode;
}

sealed class PlatformPurchaseResult {
  const PlatformPurchaseResult();
}

final class PlatformPurchaseSuccess extends PlatformPurchaseResult {
  const PlatformPurchaseSuccess(this.transaction);
  final PaymentTransaction transaction;
}

final class PlatformPurchaseUserCancelled extends PlatformPurchaseResult {
  const PlatformPurchaseUserCancelled();
}

final class PlatformPurchasePending extends PlatformPurchaseResult {
  const PlatformPurchasePending({this.message});
  final String? message;
}

final class PlatformPurchaseError extends PlatformPurchaseResult {
  const PlatformPurchaseError({
    required this.errorCode,
    required this.errorMessage,
  });

  final String errorCode;
  final String errorMessage;
}

abstract interface class PlatformBillingService {
  Future<void> initialize();

  Future<List<PlatformProductDetails>> getStoreProducts(
    List<String> storeProductIds,
  );

  Future<PlatformPurchaseResult> purchaseProduct(
    String storeProductId, {
    String? oldStoreProductId,
    ProrationMode? prorationMode,
  });

  Future<List<PaymentTransaction>> restorePurchases();

  Future<void> presentCodeRedemptionSheet();

  Future<void> presentManageSubscriptions();

  void dispose();
}
