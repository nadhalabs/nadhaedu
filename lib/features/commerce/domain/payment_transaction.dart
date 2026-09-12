import 'package:flutter/foundation.dart';

enum CommerceProvider {
  appleAppStore,
  googlePlay,
  stripe,
  mock;

  String get displayName => switch (this) {
    CommerceProvider.appleAppStore => 'Apple App Store',
    CommerceProvider.googlePlay => 'Google Play',
    CommerceProvider.stripe => 'Stripe',
    CommerceProvider.mock => 'Development Mock',
  };
}

enum PaymentTransactionStatus {
  pending,
  success,
  failed,
  cancelled;

  bool get isCompleted => this == PaymentTransactionStatus.success;
  bool get isFailed => this == PaymentTransactionStatus.failed;
  bool get isCancelled => this == PaymentTransactionStatus.cancelled;
  bool get isPending => this == PaymentTransactionStatus.pending;
}

@immutable
final class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.provider,
    required this.providerTransactionId,
    required this.receiptPayload,
    required this.status,
    required this.timestamp,
    this.amountCents,
    this.currencyCode,
    this.idempotencyKey,
    this.errorCode,
    this.errorMessage,
    this.metadata = const {},
  });

  final String id;
  final CommerceProvider provider;
  final String providerTransactionId;
  final String receiptPayload;
  final PaymentTransactionStatus status;
  final DateTime timestamp;
  final int? amountCents;
  final String? currencyCode;
  final String? idempotencyKey;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, Object?> metadata;

  bool get isSuccessful => status == PaymentTransactionStatus.success;

  PaymentTransaction copyWith({
    String? id,
    CommerceProvider? provider,
    String? providerTransactionId,
    String? receiptPayload,
    PaymentTransactionStatus? status,
    DateTime? timestamp,
    int? amountCents,
    String? currencyCode,
    String? idempotencyKey,
    String? errorCode,
    String? errorMessage,
    Map<String, Object?>? metadata,
  }) {
    return PaymentTransaction(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      providerTransactionId:
          providerTransactionId ?? this.providerTransactionId,
      receiptPayload: receiptPayload ?? this.receiptPayload,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      amountCents: amountCents ?? this.amountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          provider == other.provider &&
          providerTransactionId == other.providerTransactionId &&
          status == other.status &&
          idempotencyKey == other.idempotencyKey;

  @override
  int get hashCode =>
      Object.hash(id, provider, providerTransactionId, status, idempotencyKey);
}
