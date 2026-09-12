import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';

void main() {
  group('PaymentTransaction Domain Tests', () {
    test('instantiates and verifies successful status and properties', () {
      final now = DateTime.now().toUtc();
      final tx = PaymentTransaction(
        id: 'tx_123',
        provider: CommerceProvider.appleAppStore,
        providerTransactionId: 'app_store_tx_999',
        receiptPayload: 'receipt_payload_base64',
        status: PaymentTransactionStatus.success,
        timestamp: now,
        amountCents: 1499,
        currencyCode: 'USD',
        idempotencyKey: 'idemp_abc_123',
      );

      expect(tx.id, 'tx_123');
      expect(tx.provider, CommerceProvider.appleAppStore);
      expect(tx.isSuccessful, isTrue);
      expect(tx.status.isCompleted, isTrue);
      expect(tx.status.isFailed, isFalse);
      expect(tx.status.isCancelled, isFalse);
      expect(tx.status.isPending, isFalse);
      expect(tx.amountCents, 1499);
      expect(tx.currencyCode, 'USD');
      expect(tx.idempotencyKey, 'idemp_abc_123');
    });

    test('copyWith modifies attributes correctly', () {
      final now = DateTime.now().toUtc();
      final tx = PaymentTransaction(
        id: 'tx_123',
        provider: CommerceProvider.googlePlay,
        providerTransactionId: 'play_tx_111',
        receiptPayload: 'token_payload',
        status: PaymentTransactionStatus.pending,
        timestamp: now,
      );

      final updated = tx.copyWith(
        status: PaymentTransactionStatus.success,
        amountCents: 999,
        currencyCode: 'USD',
      );

      expect(updated.id, 'tx_123');
      expect(updated.status, PaymentTransactionStatus.success);
      expect(updated.amountCents, 999);
      expect(updated.currencyCode, 'USD');
    });

    test('equality and hashCode evaluate correctly', () {
      final now = DateTime.now().toUtc();
      final tx1 = PaymentTransaction(
        id: 'tx_123',
        provider: CommerceProvider.stripe,
        providerTransactionId: 'ch_123',
        receiptPayload: 'pi_123',
        status: PaymentTransactionStatus.success,
        timestamp: now,
        idempotencyKey: 'key1',
      );

      final tx2 = PaymentTransaction(
        id: 'tx_123',
        provider: CommerceProvider.stripe,
        providerTransactionId: 'ch_123',
        receiptPayload: 'pi_123',
        status: PaymentTransactionStatus.success,
        timestamp: now,
        idempotencyKey: 'key1',
      );

      expect(tx1, equals(tx2));
      expect(tx1.hashCode, equals(tx2.hashCode));
    });
  });
}
