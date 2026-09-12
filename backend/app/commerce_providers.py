import asyncio
import base64
import json
import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx
import stripe
from appstoreserverlibrary.api_client import APIException, AsyncAppStoreServerAPIClient
from appstoreserverlibrary.models.Environment import Environment as AppleEnvironment
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier, VerificationException
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import id_token as google_id_token
from google.oauth2 import service_account

from .config import Settings, get_settings
from .errors import APIError

logger = logging.getLogger(__name__)


@dataclass
class VerificationResult:
    is_verified: bool
    provider: str
    provider_transaction_id: str
    provider_product_id: str
    purchase_date: datetime
    amount_cents: int | None = None
    currency_code: str | None = "USD"
    expiration_date: datetime | None = None
    is_trial: bool = False
    is_auto_renewing: bool = True
    status: str = "success"
    error_message: str | None = None
    raw_data: dict = field(default_factory=dict)


@dataclass
class ProviderWebhookEvent:
    event_id: str
    event_type: (
        str  # RENEWAL, CANCELLATION, EXPIRATION, REFUND, REVOCATION, GRACE_PERIOD, BILLING_RETRY
    )
    provider: str
    provider_transaction_id: str
    original_transaction_id: str | None = None
    provider_product_id: str | None = None
    effective_date: datetime = field(default_factory=lambda: datetime.now(UTC))
    expiration_date: datetime | None = None
    is_grace_period: bool = False
    raw_payload: dict = field(default_factory=dict)


class PaymentProviderVerifier(ABC):
    @abstractmethod
    async def verify_transaction(
        self,
        *,
        provider_transaction_id: str,
        receipt_payload: str | None = None,
        candidate_product_id: str | None = None,
        expected_account_id: str | None = None,
    ) -> VerificationResult:
        """Verify transaction authenticity directly with provider authority."""

    @abstractmethod
    async def parse_and_verify_webhook(
        self, headers: dict[str, str], body: bytes
    ) -> ProviderWebhookEvent:
        """Verify cryptographic signature and parse asynchronous server notification."""


class MockPaymentProviderVerifier(PaymentProviderVerifier):
    """Deterministic fixture provider verifier for development and integration test suites."""

    async def verify_transaction(
        self,
        *,
        provider_transaction_id: str,
        receipt_payload: str | None = None,
        candidate_product_id: str | None = None,
        expected_account_id: str | None = None,
    ) -> VerificationResult:
        now = datetime.now(UTC)

        # Rejection fixture triggers
        if receipt_payload and "INVALID" in receipt_payload.upper():
            return VerificationResult(
                is_verified=False,
                provider="mock",
                provider_transaction_id=provider_transaction_id,
                provider_product_id=candidate_product_id or "unknown",
                purchase_date=now,
                status="failed",
                error_message="Receipt validation rejected by provider authority.",
            )

        if "FAIL" in provider_transaction_id.upper():
            return VerificationResult(
                is_verified=False,
                provider="mock",
                provider_transaction_id=provider_transaction_id,
                provider_product_id=candidate_product_id or "unknown",
                purchase_date=now,
                status="failed",
                error_message="Transaction marked as failed by payment gateway.",
            )

        # Detect store product or fallback
        store_product_id = candidate_product_id or "com.learningplatform.subscription.pro.monthly"
        if receipt_payload and "com.learningplatform" in receipt_payload:
            for part in receipt_payload.split():
                if part.startswith("com.learningplatform"):
                    store_product_id = part.strip()
                    break
        elif candidate_product_id is None and provider_transaction_id.startswith(
            "com.learningplatform."
        ):
            # Test-only convention: fixtures use the store product as the transaction ID.
            store_product_id = provider_transaction_id

        is_annual = "annual" in store_product_id.lower()
        is_course = "course" in store_product_id.lower()
        is_bundle = "bundle" in store_product_id.lower()

        expiration = None
        if not is_course and not is_bundle:
            expiration = now + timedelta(days=365 if is_annual else 30)

        return VerificationResult(
            is_verified=True,
            provider="mock",
            provider_transaction_id=provider_transaction_id,
            provider_product_id=store_product_id,
            purchase_date=now,
            amount_cents=11999 if is_annual else (4900 if is_course else 1499),
            currency_code="USD",
            expiration_date=expiration,
            is_trial="trial" in store_product_id.lower(),
            is_auto_renewing=not (is_course or is_bundle),
            status="success",
            raw_data={"receipt": receipt_payload, "mock_verified": True},
        )

    async def parse_and_verify_webhook(
        self, headers: dict[str, str], body: bytes
    ) -> ProviderWebhookEvent:
        try:
            data = json.loads(body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            raise APIError(400, "INVALID_WEBHOOK_PAYLOAD", "Malformed JSON body.")

        event_id = (
            data.get("eventId")
            or data.get("id")
            or f"mock_evt_{int(datetime.now(UTC).timestamp())}"
        )
        event_type = data.get("eventType", "RENEWAL").upper()
        tx_id = data.get("transactionId", "mock_tx_001")
        orig_id = data.get("originalTransactionId", tx_id)
        prod_id = data.get("productId", "com.learningplatform.subscription.pro.monthly")

        now = datetime.now(UTC)
        effective = now
        if data.get("effectiveDate"):
            effective = datetime.fromisoformat(str(data["effectiveDate"]))
        exp = effective + timedelta(days=30)
        if data.get("expirationDate"):
            exp = datetime.fromisoformat(str(data["expirationDate"]))
        if event_type in ("EXPIRATION", "REVOCATION", "REFUND"):
            exp = effective

        return ProviderWebhookEvent(
            event_id=event_id,
            event_type=event_type,
            provider="mock",
            provider_transaction_id=tx_id,
            original_transaction_id=orig_id,
            provider_product_id=prod_id,
            effective_date=effective,
            expiration_date=exp,
            is_grace_period=event_type == "GRACE_PERIOD",
            raw_payload=data,
        )


class AppleStoreKitVerifier(PaymentProviderVerifier):
    """Apple App Store Server API / JWS receipt verifier."""

    def __init__(self, settings: Settings):
        self.settings = settings
        self.is_configured = bool(
            getattr(settings, "apple_key_id", "")
            and getattr(settings, "apple_issuer_id", "")
            and getattr(settings, "apple_private_key", "")
            and getattr(settings, "apple_bundle_id", "")
            and getattr(settings, "apple_root_certificate_paths", "")
            and getattr(settings, "apple_app_id", None)
        )

    def _environment(self) -> AppleEnvironment:
        return (
            AppleEnvironment.SANDBOX
            if self.settings.apple_environment.lower() == "sandbox"
            else AppleEnvironment.PRODUCTION
        )

    def _signed_data_verifier(self) -> SignedDataVerifier:
        try:
            certificates = [
                Path(path.strip()).read_bytes()
                for path in self.settings.apple_root_certificate_paths.split(",")
                if path.strip()
            ]
        except OSError as error:
            raise APIError(
                503, "PROVIDER_UNAVAILABLE", "Apple trust roots are unavailable."
            ) from error
        if not certificates:
            raise APIError(503, "PROVIDER_UNAVAILABLE", "Apple trust roots are unavailable.")
        return SignedDataVerifier(
            certificates,
            True,
            self._environment(),
            self.settings.apple_bundle_id,
            self.settings.apple_app_id,
        )

    def _client(self) -> AsyncAppStoreServerAPIClient:
        return AsyncAppStoreServerAPIClient(
            self.settings.apple_private_key.encode(),
            self.settings.apple_key_id,
            self.settings.apple_issuer_id,
            self.settings.apple_bundle_id,
            self._environment(),
        )

    async def verify_transaction(
        self,
        *,
        provider_transaction_id: str,
        receipt_payload: str | None = None,
        candidate_product_id: str | None = None,
        expected_account_id: str | None = None,
    ) -> VerificationResult:
        if not self.is_configured:
            raise APIError(
                503,
                "PROVIDER_UNAVAILABLE",
                "Apple App Store verification is not configured on this server.",
            )

        client = self._client()
        try:
            response = await client.get_transaction_info(provider_transaction_id)
            transaction = self._signed_data_verifier().verify_and_decode_signed_transaction(
                response.signedTransactionInfo
            )
        except (APIException, VerificationException, ValueError, TypeError) as error:
            raise APIError(
                422, "PROVIDER_VERIFICATION_FAILED", "Apple transaction verification failed."
            ) from error
        finally:
            await client.async_close()
        if transaction.transactionId != provider_transaction_id:
            raise APIError(422, "PROVIDER_TRANSACTION_MISMATCH", "Apple transaction ID mismatch.")
        if candidate_product_id and transaction.productId != candidate_product_id:
            raise APIError(422, "PROVIDER_PRODUCT_MISMATCH", "Apple product ID mismatch.")
        if not expected_account_id or transaction.appAccountToken != expected_account_id:
            raise APIError(403, "PROVIDER_ACCOUNT_MISMATCH", "Apple transaction account mismatch.")
        if transaction.revocationDate is not None:
            return VerificationResult(
                False,
                "appleAppStore",
                provider_transaction_id,
                transaction.productId or "",
                datetime.fromtimestamp((transaction.purchaseDate or 0) / 1000, UTC),
                status="revoked",
                error_message="Apple reports the transaction as revoked.",
            )
        return VerificationResult(
            True,
            "appleAppStore",
            provider_transaction_id,
            transaction.productId or "",
            datetime.fromtimestamp((transaction.purchaseDate or 0) / 1000, UTC),
            amount_cents=(transaction.price // 10) if transaction.price is not None else None,
            currency_code=transaction.currency,
            expiration_date=(
                datetime.fromtimestamp(transaction.expiresDate / 1000, UTC)
                if transaction.expiresDate
                else None
            ),
            status="success",
            raw_data={"originalTransactionId": transaction.originalTransactionId},
        )

    async def parse_and_verify_webhook(
        self, headers: dict[str, str], body: bytes
    ) -> ProviderWebhookEvent:
        if not self.is_configured:
            raise APIError(503, "PROVIDER_UNCONFIGURED", "Apple webhook secret is not configured.")

        try:
            payload = json.loads(body)
            signed_payload = payload["signedPayload"]
            notification = self._signed_data_verifier().verify_and_decode_notification(
                signed_payload
            )
            if not notification.data or not notification.data.signedTransactionInfo:
                raise ValueError("missing transaction")
            transaction = self._signed_data_verifier().verify_and_decode_signed_transaction(
                notification.data.signedTransactionInfo
            )
        except (
            UnicodeDecodeError,
            json.JSONDecodeError,
            KeyError,
            VerificationException,
            ValueError,
        ) as error:
            raise APIError(
                401, "WEBHOOK_SIGNATURE_INVALID", "Apple notification verification failed."
            ) from error
        event_type = notification.rawNotificationType or (
            notification.notificationType.value if notification.notificationType else ""
        )
        return ProviderWebhookEvent(
            event_id=notification.notificationUUID or "",
            event_type=event_type,
            provider="appleAppStore",
            provider_transaction_id=transaction.transactionId or "",
            original_transaction_id=transaction.originalTransactionId,
            provider_product_id=transaction.productId,
            effective_date=datetime.fromtimestamp((notification.signedDate or 0) / 1000, UTC),
            expiration_date=(
                datetime.fromtimestamp(transaction.expiresDate / 1000, UTC)
                if transaction.expiresDate
                else None
            ),
            raw_payload={"notificationUUID": notification.notificationUUID, "type": event_type},
        )


class GooglePlayBillingVerifier(PaymentProviderVerifier):
    """Google Play Billing AndroidPublisher API verifier."""

    def __init__(self, settings: Settings):
        self.settings = settings
        self.is_configured = bool(
            getattr(settings, "google_play_service_account_json", "")
            and getattr(settings, "google_play_package_name", "")
            and getattr(settings, "google_play_pubsub_audience", "")
            and getattr(settings, "google_play_pubsub_service_account", "")
        )

    def _credentials(self):
        try:
            info = json.loads(self.settings.google_play_service_account_json)
            return service_account.Credentials.from_service_account_info(
                info, scopes=["https://www.googleapis.com/auth/androidpublisher"]
            )
        except (ValueError, TypeError, KeyError) as error:
            raise APIError(
                503, "PROVIDER_UNAVAILABLE", "Google Play credentials are invalid."
            ) from error

    async def verify_transaction(
        self,
        *,
        provider_transaction_id: str,
        receipt_payload: str | None = None,
        candidate_product_id: str | None = None,
        expected_account_id: str | None = None,
    ) -> VerificationResult:
        if not self.is_configured:
            raise APIError(
                503,
                "PROVIDER_UNAVAILABLE",
                "Google Play Billing verification is not configured on this server.",
            )

        credentials = self._credentials()
        await asyncio.to_thread(credentials.refresh, GoogleAuthRequest())
        base = (
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
            f"{self.settings.google_play_package_name}/purchases"
        )
        headers = {"Authorization": f"Bearer {credentials.token}"}
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{base}/subscriptionsv2/tokens/{provider_transaction_id}", headers=headers
            )
            is_subscription = response.status_code != 404
            if response.status_code == 404:
                response = await client.get(
                    f"{base}/productsv2/tokens/{provider_transaction_id}", headers=headers
                )
        if response.status_code == 404:
            raise APIError(
                404, "PROVIDER_TRANSACTION_NOT_FOUND", "Google Play transaction was not found."
            )
        if response.status_code != 200:
            raise APIError(503, "PROVIDER_UNAVAILABLE", "Google Play verification is unavailable.")
        try:
            data = response.json()
            account = data.get("externalAccountIdentifiers", {}).get("obfuscatedExternalAccountId")
            line = (data.get("lineItems") or data.get("productLineItem") or [])[0]
            product_id = line.get("productId")
        except (ValueError, IndexError, TypeError, AttributeError) as error:
            raise APIError(
                422, "PROVIDER_RESPONSE_INVALID", "Google Play response is malformed."
            ) from error
        if not expected_account_id or account != expected_account_id:
            raise APIError(
                403, "PROVIDER_ACCOUNT_MISMATCH", "Google Play transaction account mismatch."
            )
        if not product_id or (candidate_product_id and product_id != candidate_product_id):
            raise APIError(
                422, "PROVIDER_PRODUCT_MISMATCH", "Google Play product mapping mismatch."
            )
        state = (
            data.get("subscriptionState")
            if is_subscription
            else data.get("purchaseStateContext", {}).get("purchaseState")
        )
        verified_states = {
            "SUBSCRIPTION_STATE_ACTIVE",
            "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
            "PURCHASE_STATE_PURCHASED",
        }
        verified = state in verified_states
        expiry_value = line.get("expiryTime") if is_subscription else None
        return VerificationResult(
            verified,
            "googlePlay",
            provider_transaction_id,
            product_id,
            datetime.fromisoformat(data.get("startTime", datetime.now(UTC).isoformat())),
            expiration_date=(datetime.fromisoformat(expiry_value) if expiry_value else None),
            status=state or "unknown",
            error_message=None if verified else "Google Play reports the purchase as inactive.",
            raw_data={"latestOrderId": data.get("latestOrderId"), "state": state},
        )

    async def parse_and_verify_webhook(
        self, headers: dict[str, str], body: bytes
    ) -> ProviderWebhookEvent:
        if not self.is_configured:
            raise APIError(503, "PROVIDER_UNCONFIGURED", "Google Play webhook is unconfigured.")

        authorization = headers.get("authorization", "")
        if not authorization.startswith("Bearer "):
            raise APIError(
                401, "WEBHOOK_SIGNATURE_MISSING", "Google Pub/Sub identity token is missing."
            )
        try:
            claims = await asyncio.to_thread(
                google_id_token.verify_oauth2_token,
                authorization[7:],
                GoogleAuthRequest(),
                self.settings.google_play_pubsub_audience,
            )
            if claims.get("email") != self.settings.google_play_pubsub_service_account:
                raise ValueError("service account mismatch")
            envelope = json.loads(body)
            message = envelope["message"]
            data = json.loads(base64.b64decode(message["data"], validate=True))
        except (ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
            raise APIError(
                401, "WEBHOOK_SIGNATURE_INVALID", "Google Pub/Sub verification failed."
            ) from error
        notice = data.get("subscriptionNotification") or data.get("oneTimeProductNotification")
        if not notice or data.get("packageName") != self.settings.google_play_package_name:
            raise APIError(422, "INVALID_WEBHOOK_PAYLOAD", "Google Play notification is malformed.")
        event_map = {
            1: "RENEWAL",
            2: "RENEWAL",
            3: "CANCELLATION",
            4: "RENEWAL",
            5: "GRACE_PERIOD",
            6: "GRACE_PERIOD",
            10: "DID_CHANGE_RENEWAL_STATUS",
            12: "REVOCATION",
            13: "EXPIRATION",
            20: "RENEWAL",
        }
        event_type = event_map.get(notice.get("notificationType"))
        if not event_type:
            raise APIError(422, "UNSUPPORTED_PROVIDER_EVENT", "Unsupported Google Play event type.")
        token = notice.get("purchaseToken")
        if not token or not message.get("messageId"):
            raise APIError(422, "INVALID_WEBHOOK_PAYLOAD", "Google Play identifiers are missing.")
        return ProviderWebhookEvent(
            event_id=message["messageId"],
            event_type=event_type,
            provider="googlePlay",
            provider_transaction_id=token,
            original_transaction_id=token,
            provider_product_id=notice.get("subscriptionId") or notice.get("sku"),
            effective_date=datetime.fromtimestamp(int(data.get("eventTimeMillis", 0)) / 1000, UTC),
            raw_payload={"messageId": message["messageId"], "type": event_type},
        )


class StripePaymentVerifier(PaymentProviderVerifier):
    """Stripe Payment Intents and Checkout Session verifier."""

    def __init__(self, settings: Settings):
        self.settings = settings
        self.is_configured = bool(getattr(settings, "stripe_api_key", ""))

    async def verify_transaction(
        self,
        *,
        provider_transaction_id: str,
        receipt_payload: str | None = None,
        candidate_product_id: str | None = None,
        expected_account_id: str | None = None,
    ) -> VerificationResult:
        if not self.is_configured:
            raise APIError(
                503,
                "PROVIDER_UNAVAILABLE",
                "Stripe payment verification is not configured on this server.",
            )

        try:
            intent = await asyncio.to_thread(
                stripe.StripeClient(self.settings.stripe_api_key).v1.payment_intents.retrieve,
                provider_transaction_id,
            )
        except stripe.StripeError as error:
            raise APIError(
                422, "PROVIDER_VERIFICATION_FAILED", "Stripe transaction verification failed."
            ) from error
        metadata = dict(intent.metadata or {})
        if intent.id != provider_transaction_id:
            raise APIError(422, "PROVIDER_TRANSACTION_MISMATCH", "Stripe transaction ID mismatch.")
        if intent.status != "succeeded" or intent.amount_received < intent.amount:
            return VerificationResult(
                False,
                "stripe",
                provider_transaction_id,
                metadata.get("product_id", ""),
                datetime.fromtimestamp(intent.created, UTC),
                status=intent.status,
                error_message="Stripe has not settled this payment.",
            )
        if not expected_account_id or metadata.get("learner_id") != expected_account_id:
            raise APIError(403, "PROVIDER_ACCOUNT_MISMATCH", "Stripe transaction account mismatch.")
        product_id = metadata.get("product_id")
        if not product_id or (candidate_product_id and product_id != candidate_product_id):
            raise APIError(422, "PROVIDER_PRODUCT_MISMATCH", "Stripe product mapping mismatch.")
        return VerificationResult(
            True,
            "stripe",
            provider_transaction_id,
            product_id,
            datetime.fromtimestamp(intent.created, UTC),
            amount_cents=intent.amount_received,
            currency_code=intent.currency.upper(),
            status="success",
            raw_data={"customerId": intent.customer, "paymentIntentStatus": intent.status},
        )

    async def parse_and_verify_webhook(
        self, headers: dict[str, str], body: bytes
    ) -> ProviderWebhookEvent:
        webhook_secret = getattr(self.settings, "stripe_webhook_secret", "")
        if not webhook_secret:
            raise APIError(503, "PROVIDER_UNCONFIGURED", "Stripe webhook secret is not configured.")

        signature_header = headers.get("stripe-signature")
        if not signature_header:
            raise APIError(401, "WEBHOOK_SIGNATURE_MISSING", "Missing Stripe-Signature header.")

        try:
            event = stripe.Webhook.construct_event(body, signature_header, webhook_secret)
        except (ValueError, stripe.SignatureVerificationError):
            raise APIError(401, "WEBHOOK_SIGNATURE_INVALID", "Failed to verify webhook signature.")
        event_map = {
            "invoice.paid": "RENEWAL",
            "customer.subscription.deleted": "EXPIRATION",
            "customer.subscription.updated": "DID_CHANGE_RENEWAL_STATUS",
            "charge.refunded": "REFUND",
            "charge.dispute.created": "REVOCATION",
        }
        event_type = event_map.get(event.type)
        if not event_type:
            raise APIError(422, "UNSUPPORTED_PROVIDER_EVENT", "Unsupported Stripe event type.")
        obj = event.data.object
        metadata = dict(getattr(obj, "metadata", {}) or {})
        transaction_id = (
            getattr(obj, "payment_intent", None)
            or getattr(obj, "subscription", None)
            or getattr(obj, "id", None)
        )
        original_id = getattr(obj, "subscription", None) or getattr(obj, "id", None)
        if not transaction_id or not event.id:
            raise APIError(422, "INVALID_WEBHOOK_PAYLOAD", "Stripe event identifiers are missing.")
        return ProviderWebhookEvent(
            event_id=event.id,
            event_type=event_type,
            provider="stripe",
            provider_transaction_id=transaction_id,
            original_transaction_id=original_id,
            provider_product_id=metadata.get("product_id"),
            effective_date=datetime.fromtimestamp(event.created, UTC),
            expiration_date=(
                datetime.fromtimestamp(obj.current_period_end, UTC)
                if getattr(obj, "current_period_end", None)
                else None
            ),
            raw_payload={"id": event.id, "type": event.type},
        )


class UnconfiguredPaymentProviderVerifier(PaymentProviderVerifier):
    """Fail-closed verifier for production when provider is unknown or missing."""

    async def verify_transaction(
        self,
        *,
        provider_transaction_id: str,
        receipt_payload: str | None = None,
        candidate_product_id: str | None = None,
        expected_account_id: str | None = None,
    ) -> VerificationResult:
        raise APIError(
            503,
            "PROVIDER_UNCONFIGURED",
            "Payment provider verification is unconfigured for this platform.",
        )

    async def parse_and_verify_webhook(
        self, headers: dict[str, str], body: bytes
    ) -> ProviderWebhookEvent:
        raise APIError(
            503,
            "PROVIDER_UNCONFIGURED",
            "Webhook processing is unconfigured for this platform.",
        )


def get_payment_verifier(
    provider: str, settings: Settings | None = None
) -> PaymentProviderVerifier:
    cfg = settings or get_settings()
    normalized = provider.lower().replace("_", "").replace("-", "")

    if normalized in ("appleappstore", "apple", "appstore", "storekit"):
        return AppleStoreKitVerifier(cfg)
    elif normalized in ("googleplay", "google", "playstore"):
        return GooglePlayBillingVerifier(cfg)
    elif normalized in ("stripe", "web"):
        return StripePaymentVerifier(cfg)
    elif normalized in ("mock", "test", "dev") and cfg.environment in {
        "development",
        "test",
    }:
        return MockPaymentProviderVerifier()

    return UnconfiguredPaymentProviderVerifier()
