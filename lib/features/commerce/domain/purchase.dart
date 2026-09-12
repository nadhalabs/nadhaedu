import 'package:flutter/foundation.dart';

enum CommerceProductType {
  course,
  bundle,
  certificate;

  String get displayName => switch (this) {
    CommerceProductType.course => 'Course',
    CommerceProductType.bundle => 'Course Bundle',
    CommerceProductType.certificate => 'Certificate',
  };
}

enum PurchaseStatus {
  completed,
  refunded,
  revoked,
  failed;

  bool get isActive => this == PurchaseStatus.completed;
}

@immutable
final class Purchase {
  const Purchase({
    required this.id,
    required this.learnerId,
    required this.productId,
    required this.productType,
    required this.orderId,
    required this.transactionId,
    required this.status,
    required this.purchasedAt,
    this.amountCents,
    this.currencyCode,
    this.metadata = const {},
  });

  final String id;
  final String learnerId;
  final String productId;
  final CommerceProductType productType;
  final String orderId;
  final String transactionId;
  final PurchaseStatus status;
  final DateTime purchasedAt;
  final int? amountCents;
  final String? currencyCode;
  final Map<String, Object?> metadata;

  bool get isActive => status.isActive;

  Purchase copyWith({
    String? id,
    String? learnerId,
    String? productId,
    CommerceProductType? productType,
    String? orderId,
    String? transactionId,
    PurchaseStatus? status,
    DateTime? purchasedAt,
    int? amountCents,
    String? currencyCode,
    Map<String, Object?>? metadata,
  }) {
    return Purchase(
      id: id ?? this.id,
      learnerId: learnerId ?? this.learnerId,
      productId: productId ?? this.productId,
      productType: productType ?? this.productType,
      orderId: orderId ?? this.orderId,
      transactionId: transactionId ?? this.transactionId,
      status: status ?? this.status,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      amountCents: amountCents ?? this.amountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Purchase &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          learnerId == other.learnerId &&
          productId == other.productId &&
          orderId == other.orderId &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, learnerId, productId, orderId, status);
}
