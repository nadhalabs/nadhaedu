import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/features/commerce/data/remote_commerce_data_source.dart';
import 'package:learning_platform/features/commerce/domain/payment_transaction.dart';
import 'package:learning_platform/features/commerce/domain/subscription.dart';

void main() {
  group('RemoteCommerceDataSource Tests', () {
    test('fetches subscription plans via GET /api/v1/commerce/plans', () async {
      final client = _MockApiClient(
        getResponse: {
          'items': [
            {
              'id': 'plan_pro_monthly',
              'tier': 'pro',
              'billingInterval': 'monthly',
              'name': 'Pro Monthly',
              'description': 'Full access',
              'priceCents': 1499,
              'formattedPrice': '\$14.99',
              'currencyCode': 'USD',
              'trialDays': 7,
              'benefits': ['Feature 1'],
            },
          ],
        },
      );

      final dataSource = RemoteCommerceDataSource(client);
      final plans = await dataSource.fetchSubscriptionPlans();

      expect(client.lastGetPath, '/api/v1/commerce/plans');
      expect(plans.length, 1);
      expect(plans.first.id, 'plan_pro_monthly');
      expect(plans.first.tier, SubscriptionTier.pro);
    });

    test('verifies transaction and passes Idempotency-Key header', () async {
      final client = _MockApiClient(
        postResponse: {
          'verified': true,
          'subscription': {
            'id': 'sub_123',
            'learnerId': 'learner-1',
            'planId': 'plan_pro_annual',
            'tier': 'pro',
            'billingInterval': 'annual',
            'status': 'active',
            'currentPeriodStart': '2026-08-31T00:00:00.000Z',
            'currentPeriodEnd': '2027-08-31T00:00:00.000Z',
          },
          'grantedEntitlements': [
            {
              'id': 'ent_123',
              'learnerId': 'learner-1',
              'source': {
                'type': 'subscription',
                'planId': 'plan_pro_annual',
                'tier': 'Pro',
              },
              'status': 'active',
              'validFrom': '2026-08-31T00:00:00.000Z',
              'validUntil': '2027-08-31T00:00:00.000Z',
            },
          ],
        },
      );

      final dataSource = RemoteCommerceDataSource(client);
      final tx = PaymentTransaction(
        id: 'tx_abc',
        provider: CommerceProvider.appleAppStore,
        providerTransactionId: 'app_store_1',
        receiptPayload: 'payload',
        status: PaymentTransactionStatus.success,
        timestamp: DateTime.now().toUtc(),
      );

      final result = await dataSource.verifyTransaction(
        transaction: tx,
        learnerId: 'learner-1',
        idempotencyKey: 'idemp-xyz-999',
        couponCode: 'SAVE20',
      );

      expect(client.lastPostPath, '/api/v1/commerce/transactions/verify');
      expect(client.lastHeaders?['Idempotency-Key'], 'idemp-xyz-999');
      expect(client.lastBody?['couponCode'], 'SAVE20');
      expect(result.isSuccess, isTrue);
      expect(result.subscription?.id, 'sub_123');
      expect(result.grantedEntitlements.length, 1);
    });
  });
}

final class _MockApiClient implements ApiClient {
  _MockApiClient({this.getResponse, this.postResponse});

  final Map<String, Object?>? getResponse;
  final Map<String, Object?>? postResponse;

  String? lastGetPath;
  String? lastPostPath;
  Map<String, Object?>? lastBody;
  Map<String, Object?>? lastHeaders;

  @override
  Future<Result<Map<String, Object?>>> get(
    String path, {
    Map<String, Object?> query = const {},
    bool authenticated = true,
  }) async {
    lastGetPath = path;
    return Success(getResponse ?? const {});
  }

  @override
  Future<Result<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async {
    lastPostPath = path;
    lastBody = body;
    lastHeaders = headers;
    return Success(postResponse ?? const {});
  }

  @override
  Future<Result<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async => Success(postResponse ?? const {});

  @override
  Future<Result<Map<String, Object?>>> delete(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async => const Success({});
}
