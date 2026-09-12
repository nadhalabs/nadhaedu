# Production Owner Launch Checklist

Mark each blocking item PASS only after observing the expected result in the deployed environment.

| Area | Owner action | Expected result / PASS criterion | Blocks launch |
|---|---|---|---|
| Apple | Create In-App Purchase key, install Apple PKI roots, set bundle/app IDs, configure App Store Server Notifications, then exercise sandbox purchase, renewal, cancellation, refund and restore. | Backend accepts authentic JWS/API results, rejects wrong `appAccountToken`, processes each notification once, and entitlements follow Apple state. | Yes, if Apple commerce is enabled |
| Google Play | Grant Android Publisher access to the service account, configure package name and authenticated Pub/Sub push audience/service identity, then exercise licensed test purchase and lifecycle events. | Backend rejects wrong account/package, accepts authenticated RTDN once, and entitlement state follows Play. | Yes, if Play commerce is enabled |
| Stripe | Add live/test keys, register the deployed webhook URL and signing secret, then run payment, renewal, cancellation, refund and dispute tests with learner/product metadata. | PaymentIntent ownership is verified, signatures pass only for Stripe events, replay is idempotent, and entitlement state reconciles. | Yes, if Stripe commerce is enabled |
| PostgreSQL | Provision supported PostgreSQL, run `alembic upgrade head`, confirm `alembic current` is `0007_cms_phase34`, configure pooling/PITR, run a backup and restore drill. | Readiness is green; restored database is consistent and reaches the same migration head. | Yes |
| Redis | Provision TLS/authenticated Redis and test outage/failover. | Readiness fails closed while unavailable and distributed production rate limits share state. | Yes |
| SMTP | Add relay credentials and send an authorized reset email. | Relay accepts the message and the recipient receives a usable, expiring link; failures do not claim delivery. | Yes for password recovery |
| Push | Choose and configure FCM/APNs after the remaining server delivery adapter is implemented; test real Android/iOS devices. | Provider acceptance/failure is recorded truthfully and no token crosses users. | Yes if push is launch scope |
| CDN/DNS | Configure production domains, TLS, private origin access and CDN rules. | Direct origin bypass fails; signed URLs expire and only authorize the bound asset. | Yes for protected media |
| Monitoring | Configure uptime, error, database, Redis, provider-webhook and backup alerts with an on-call recipient. | A controlled failure generates a timely actionable alert. | Yes |

