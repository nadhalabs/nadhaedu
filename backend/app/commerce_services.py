import logging
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from .commerce_providers import (
    ProviderWebhookEvent,
    get_payment_verifier,
)
from .config import Settings, get_settings
from .errors import APIError
from .models import (
    BillingInterval,
    CommerceProduct,
    CommerceProductType,
    Coupon,
    CouponRedemption,
    Course,
    Entitlement,
    EntitlementSource,
    EntitlementStatus,
    PaymentProvider,
    PaymentTransaction,
    ProviderEvent,
    ProviderEventStatus,
    ProviderProductMapping,
    Purchase,
    PurchaseStatus,
    ResourceType,
    Subscription,
    SubscriptionPlan,
    SubscriptionStatus,
)
from .schemas import RestoreTransactionItem, TransactionVerifyIn
from .services import iso, now

logger = logging.getLogger(__name__)


def plan_json(p: SubscriptionPlan, store_product_id: str | None = None) -> dict:
    return {
        "id": p.id,
        "tier": p.tier.value,
        "billingInterval": p.billing_interval.value,
        "name": p.name,
        "description": p.description,
        "priceCents": p.price_cents,
        "formattedPrice": p.formatted_price,
        "currencyCode": p.currency_code,
        "trialDays": p.trial_days,
        "introductoryOffer": p.introductory_offer_json,
        "benefits": p.benefits or [],
        "isPopular": p.is_popular,
        "isRecommended": p.is_recommended,
        "savingsPercent": p.savings_percent,
        "storeProductId": store_product_id,
    }


def course_product_json(c: CommerceProduct, store_product_id: str | None = None) -> dict:
    return {
        "id": c.id,
        "courseId": c.course_id or "",
        "title": c.title,
        "description": c.description,
        "priceCents": c.price_cents,
        "formattedPrice": c.formatted_price,
        "currencyCode": c.currency_code,
        "originalPriceCents": c.original_price_cents,
        "discountPercent": c.discount_percent,
        "features": c.features or [],
        "storeProductId": store_product_id,
    }


def bundle_product_json(b: CommerceProduct, store_product_id: str | None = None) -> dict:
    return {
        "id": b.id,
        "bundleId": b.bundle_id or b.id,
        "title": b.title,
        "description": b.description,
        "courseIds": b.course_ids or [],
        "priceCents": b.price_cents,
        "formattedPrice": b.formatted_price,
        "currencyCode": b.currency_code,
        "originalPriceCents": b.original_price_cents,
        "discountPercent": b.discount_percent,
        "features": b.features or [],
        "storeProductId": store_product_id,
    }


def coupon_json(c: Coupon) -> dict:
    return {
        "code": c.code,
        "discountType": c.discount_type.value,
        "discountValue": c.discount_value,
        "validUntil": iso(c.valid_until),
        "applicableProductIds": c.applicable_product_ids or [],
        "description": c.description,
        "valid": True,
    }


def purchase_json(p: Purchase) -> dict:
    return {
        "id": p.id,
        "learnerId": p.learner_id,
        "productId": p.product_id,
        "productType": p.product_type.value,
        "orderId": p.order_id,
        "transactionId": p.transaction_id or p.id,
        "status": p.status.value,
        "purchasedAt": iso(p.purchased_at),
        "amountCents": p.amount_cents,
        "currencyCode": p.currency_code,
        "metadata": p.metadata_json or {},
    }


def subscription_json(s: Subscription) -> dict:
    trial_dict = None
    if s.trial_start_date and s.trial_end_date:
        trial_dict = {
            "startDate": iso(s.trial_start_date),
            "endDate": iso(s.trial_end_date),
            "durationDays": s.trial_duration_days or 0,
        }
    return {
        "id": s.id,
        "learnerId": s.learner_id,
        "planId": s.plan_id,
        "tier": s.tier.value,
        "billingInterval": s.billing_interval.value,
        "status": s.status.value,
        "currentPeriodStart": iso(s.current_period_start),
        "currentPeriodEnd": iso(s.current_period_end),
        "cancelAtPeriodEnd": s.cancel_at_period_end,
        "renewsAt": iso(s.renews_at),
        "trialPeriod": trial_dict,
        "introductoryPriceCents": s.introductory_price_cents,
        "cancellationReason": s.cancellation_reason,
        "originalTransactionId": s.original_transaction_id,
        "latestTransactionId": s.latest_transaction_id,
        "metadata": s.metadata_json or {},
    }


def entitlement_json(e: Entitlement) -> dict:
    source_type = e.source.value
    meta = e.metadata_json or {}
    source_dict: dict = {"type": source_type}

    if e.source == EntitlementSource.subscription:
        source_dict["planId"] = meta.get("planId", "plan_pro")
        source_dict["tier"] = meta.get("tier", "Pro")
    elif e.source == EntitlementSource.purchase:
        source_dict["type"] = "individualPurchase"
        source_dict["orderId"] = meta.get("orderId", e.id)
    elif e.source == EntitlementSource.bundle:
        source_dict["bundleId"] = meta.get("bundleId", e.id)
        source_dict["bundleTitle"] = meta.get("bundleTitle", "Bundle")
    else:
        source_dict["planId"] = meta.get("planId", "plan_pro")
        source_dict["tier"] = meta.get("tier", "Pro")

    return {
        "id": e.id,
        "learnerId": e.learner_id,
        "source": source_dict,
        "status": e.status.value,
        "targetType": e.resource_type.value if e.resource_type else None,
        "targetId": e.resource_id,
        "validFrom": iso(e.starts_at),
        "validUntil": iso(e.expires_at),
        "metadata": meta,
    }


def ensure_utc(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    return dt.replace(tzinfo=UTC) if dt.tzinfo is None else dt


async def validate_coupon_logic(
    db: AsyncSession,
    code: str,
    product_id: str | None = None,
    *,
    lock_for_redemption: bool = False,
) -> Coupon | None:
    clean_code = code.strip().upper()
    query = select(Coupon).where(Coupon.code == clean_code)
    if lock_for_redemption:
        query = query.with_for_update()
    c = await db.scalar(query)
    if not c or not c.is_active:
        return None

    current = now()
    v_from = ensure_utc(c.valid_from)
    v_until = ensure_utc(c.valid_until)
    if v_from and v_from > current:
        return None
    if v_until and v_until <= current:
        return None
    if c.max_redemptions is not None and c.redemption_count >= c.max_redemptions:
        return None

    if product_id and c.applicable_product_ids and product_id not in c.applicable_product_ids:
        return None

    return c


async def verify_and_process_transaction(
    db: AsyncSession,
    learner_id: str,
    body: TransactionVerifyIn,
    settings: Settings | None = None,
) -> dict:
    cfg = settings or get_settings()

    # Invariant: cross-user purchase hijacking prevention
    if body.learner_id != learner_id:
        raise APIError(
            403, "FORBIDDEN", "Transaction learner ID does not match authenticated user."
        )

    try:
        provider_enum = PaymentProvider(body.provider)
    except ValueError as error:
        raise APIError(400, "UNSUPPORTED_PROVIDER", "Payment provider is not supported.") from error

    if db.bind and db.bind.dialect.name == "postgresql":
        await db.execute(
            select(
                func.pg_advisory_xact_lock(
                    func.hashtextextended(
                        f"commerce:{provider_enum.value}:{body.provider_transaction_id}", 0
                    )
                )
            )
        )

    # 1. Check existing payment transaction for idempotency / replay
    existing_tx = await db.scalar(
        select(PaymentTransaction).where(
            PaymentTransaction.provider == provider_enum,
            PaymentTransaction.provider_transaction_id == body.provider_transaction_id,
        )
    )

    if existing_tx:
        if existing_tx.learner_id != learner_id:
            raise APIError(
                409,
                "TRANSACTION_OWNERSHIP_CONFLICT",
                "This provider transaction is already owned by another learner.",
            )
        if existing_tx.status != "success":
            return {
                "verified": False,
                "purchase": None,
                "subscription": None,
                "grantedEntitlements": [],
                "errorMessage": existing_tx.error_message or "Transaction verification failed.",
            }
        # Check if corresponding purchase or subscription exists
        existing_purchase = await db.scalar(
            select(Purchase).where(Purchase.transaction_id == existing_tx.id)
        )
        existing_sub = await db.scalar(
            select(Subscription).where(
                Subscription.learner_id == learner_id,
                Subscription.provider == provider_enum,
                or_(
                    Subscription.original_transaction_id == body.provider_transaction_id,
                    Subscription.latest_transaction_id == body.provider_transaction_id,
                ),
            )
        )
        linked_filters = []
        if existing_purchase:
            linked_filters.append(Entitlement.purchase_id == existing_purchase.id)
        if existing_sub:
            linked_filters.append(Entitlement.subscription_id == existing_sub.id)
        entitlements = []
        if linked_filters:
            entitlements = (
                await db.scalars(
                    select(Entitlement).where(
                        Entitlement.learner_id == learner_id,
                        or_(*linked_filters),
                    )
                )
            ).all()

        return {
            "verified": True,
            "purchase": purchase_json(existing_purchase) if existing_purchase else None,
            "subscription": subscription_json(existing_sub) if existing_sub else None,
            "grantedEntitlements": [entitlement_json(e) for e in entitlements],
            "errorMessage": None,
        }

    # 2. Authoritative Provider Verification
    verifier = get_payment_verifier(body.provider, cfg)
    verification = await verifier.verify_transaction(
        provider_transaction_id=body.provider_transaction_id,
        receipt_payload=body.receipt_payload,
        candidate_product_id=None,
        expected_account_id=learner_id,
    )

    if not verification.is_verified:
        # Record failed transaction for auditing
        failed_tx = PaymentTransaction(
            learner_id=learner_id,
            provider=provider_enum,
            provider_transaction_id=body.provider_transaction_id,
            idempotency_key=body.idempotency_key,
            status="failed",
            error_message=verification.error_message or "Payment verification failed.",
        )
        db.add(failed_tx)
        await db.flush()

        return {
            "verified": False,
            "purchase": None,
            "subscription": None,
            "grantedEntitlements": [],
            "errorMessage": verification.error_message or "Transaction verification failed.",
        }

    current = now()

    # 3. Resolve Internal Commercial Product / Plan from mapping or store ID
    store_prod_id = verification.provider_product_id

    # Check mapping table
    mapping = await db.scalar(
        select(ProviderProductMapping).where(
            ProviderProductMapping.provider == provider_enum,
            ProviderProductMapping.provider_product_id == store_prod_id,
        )
    )

    plan: SubscriptionPlan | None = None
    course_product: CommerceProduct | None = None
    bundle_product: CommerceProduct | None = None

    if mapping:
        if mapping.internal_product_type == "plan":
            plan = await db.get(SubscriptionPlan, mapping.internal_product_id)
        elif mapping.internal_product_type == "course":
            course_product = await db.get(CommerceProduct, mapping.internal_product_id)
        elif mapping.internal_product_type == "bundle":
            bundle_product = await db.get(CommerceProduct, mapping.internal_product_id)

    if not plan and not course_product and not bundle_product:
        raise APIError(
            422,
            "UNKNOWN_PROVIDER_PRODUCT",
            "The verified provider product is not mapped to an active commercial product.",
        )

    resolved_product = plan or course_product or bundle_product
    if not resolved_product or not resolved_product.is_active:
        raise APIError(422, "INACTIVE_PROVIDER_PRODUCT", "The mapped product is unavailable.")

    # 4. Record Payment Transaction
    tx = PaymentTransaction(
        learner_id=learner_id,
        provider=provider_enum,
        provider_transaction_id=body.provider_transaction_id,
        provider_product_id=store_prod_id,
        idempotency_key=body.idempotency_key,
        status="success",
        amount_cents=verification.amount_cents
        or (plan.price_cents if plan else (course_product.price_cents if course_product else None)),
        currency_code=verification.currency_code or "USD",
        receipt_payload=body.receipt_payload,
        raw_response_json=verification.raw_data,
    )
    db.add(tx)
    await db.flush()

    granted_entitlements: list[Entitlement] = []
    created_purchase: Purchase | None = None
    created_subscription: Subscription | None = None

    # 5. Handle Coupon Redemption if supplied
    if body.coupon_code:
        coupon = await validate_coupon_logic(
            db,
            body.coupon_code,
            resolved_product.id,
            lock_for_redemption=True,
        )
        if coupon:
            coupon.redemption_count += 1
            redemption = CouponRedemption(
                coupon_id=coupon.id,
                learner_id=learner_id,
                order_id=f"ORD-{tx.id[:8]}",
            )
            db.add(redemption)

    # 6. Authoritative Subscription or Purchase Creation & Entitlement Grant
    if plan:
        period_days = 365 if plan.billing_interval == BillingInterval.annual else 30
        period_end = verification.expiration_date or (current + timedelta(days=period_days))
        # Trial configuration advertises eligibility; only the provider's
        # verified transaction state can establish that this purchase is a trial.
        is_trial = verification.is_trial

        sub = Subscription(
            learner_id=learner_id,
            provider=provider_enum,
            plan_id=plan.id,
            tier=plan.tier,
            billing_interval=plan.billing_interval,
            status=SubscriptionStatus.trialing if is_trial else SubscriptionStatus.active,
            current_period_start=current,
            current_period_end=period_end,
            renews_at=period_end,
            trial_start_date=current if is_trial else None,
            trial_end_date=current + timedelta(days=plan.trial_days) if is_trial else None,
            trial_duration_days=plan.trial_days if is_trial else None,
            original_transaction_id=body.provider_transaction_id,
            latest_transaction_id=body.provider_transaction_id,
        )
        db.add(sub)
        await db.flush()
        created_subscription = sub

        entitlement = Entitlement(
            learner_id=learner_id,
            source=EntitlementSource.trial if is_trial else EntitlementSource.subscription,
            status=EntitlementStatus.active,
            starts_at=current,
            expires_at=period_end,
            subscription_id=sub.id,
            metadata_json={
                "planId": plan.id,
                "tier": plan.tier.value,
                "subscriptionId": sub.id,
                "provider": body.provider,
            },
        )
        db.add(entitlement)
        await db.flush()
        granted_entitlements.append(entitlement)

    elif course_product:
        order_id = f"ORD-{uuid.uuid4().hex[:12].upper()}"
        purchase = Purchase(
            learner_id=learner_id,
            product_id=course_product.id,
            product_type=CommerceProductType.course,
            order_id=order_id,
            transaction_id=tx.id,
            status=PurchaseStatus.completed,
            purchased_at=current,
            amount_cents=course_product.price_cents,
            currency_code=course_product.currency_code,
        )
        db.add(purchase)
        await db.flush()
        created_purchase = purchase

        entitlement = Entitlement(
            learner_id=learner_id,
            source=EntitlementSource.purchase,
            status=EntitlementStatus.active,
            resource_type=ResourceType.course,
            resource_id=course_product.course_id,
            starts_at=current,
            expires_at=None,  # perpetual
            purchase_id=purchase.id,
            metadata_json={
                "orderId": purchase.order_id,
                "productId": course_product.id,
                "courseId": course_product.course_id,
            },
        )
        db.add(entitlement)
        await db.flush()
        granted_entitlements.append(entitlement)

    elif bundle_product:
        order_id = f"ORD-{uuid.uuid4().hex[:12].upper()}"
        purchase = Purchase(
            learner_id=learner_id,
            product_id=bundle_product.id,
            product_type=CommerceProductType.bundle,
            order_id=order_id,
            transaction_id=tx.id,
            status=PurchaseStatus.completed,
            purchased_at=current,
            amount_cents=bundle_product.price_cents,
            currency_code=bundle_product.currency_code,
        )
        db.add(purchase)
        await db.flush()
        created_purchase = purchase

        if not bundle_product.course_ids:
            raise APIError(422, "EMPTY_BUNDLE", "The mapped bundle contains no courses.")
        course_ids = sorted(set(bundle_product.course_ids))
        valid_course_ids = set(
            (await db.scalars(select(Course.id).where(Course.id.in_(course_ids)))).all()
        )
        if valid_course_ids != set(course_ids):
            raise APIError(422, "INVALID_BUNDLE_SCOPE", "Bundle course scope is invalid.")
        for course_id in course_ids:
            entitlement = Entitlement(
                learner_id=learner_id,
                source=EntitlementSource.bundle,
                status=EntitlementStatus.active,
                resource_type=ResourceType.course,
                resource_id=course_id,
                starts_at=current,
                expires_at=None,
                purchase_id=purchase.id,
                metadata_json={
                    "orderId": purchase.order_id,
                    "bundleId": bundle_product.bundle_id or bundle_product.id,
                    "bundleTitle": bundle_product.title,
                },
            )
            db.add(entitlement)
            await db.flush()
            granted_entitlements.append(entitlement)

    await db.flush()

    return {
        "verified": True,
        "purchase": purchase_json(created_purchase) if created_purchase else None,
        "subscription": subscription_json(created_subscription) if created_subscription else None,
        "grantedEntitlements": [entitlement_json(e) for e in granted_entitlements],
        "errorMessage": None,
    }


async def restore_learner_purchases(
    db: AsyncSession,
    learner_id: str,
    transactions: list[RestoreTransactionItem],
    settings: Settings | None = None,
) -> dict:
    cfg = settings or get_settings()
    purchase_ids: set[str] = set()
    subscription_ids: set[str] = set()
    entitlement_ids: set[str] = set()

    for item in transactions:
        result = await verify_and_process_transaction(
            db,
            learner_id,
            TransactionVerifyIn(
                transaction_id=item.transaction_id,
                provider=item.provider,
                provider_transaction_id=item.provider_transaction_id,
                receipt_payload=item.receipt_payload,
                learner_id=learner_id,
            ),
            cfg,
        )
        if not result["verified"]:
            continue
        if result["purchase"]:
            purchase_ids.add(result["purchase"]["id"])
        if result["subscription"]:
            subscription_ids.add(result["subscription"]["id"])
        entitlement_ids.update(e["id"] for e in result["grantedEntitlements"])

    restored_purchases = (
        list(
            await db.scalars(
                select(Purchase).where(
                    Purchase.learner_id == learner_id,
                    Purchase.id.in_(purchase_ids),
                )
            )
        )
        if purchase_ids
        else []
    )
    subscriptions = (
        list(
            await db.scalars(
                select(Subscription).where(
                    Subscription.learner_id == learner_id,
                    Subscription.id.in_(subscription_ids),
                )
            )
        )
        if subscription_ids
        else []
    )
    restored_entitlements = (
        list(
            await db.scalars(
                select(Entitlement).where(
                    Entitlement.learner_id == learner_id,
                    Entitlement.id.in_(entitlement_ids),
                    Entitlement.status.in_(
                        [EntitlementStatus.active, EntitlementStatus.grace_period]
                    ),
                )
            )
        )
        if entitlement_ids
        else []
    )
    active_sub = max(subscriptions, key=lambda sub: sub.updated_at, default=None)

    return {
        "success": True,
        "restoredCount": len(restored_purchases) + (1 if active_sub else 0),
        "restoredPurchases": [purchase_json(p) for p in restored_purchases],
        "activeSubscription": subscription_json(active_sub) if active_sub else None,
        "restoredEntitlements": [entitlement_json(e) for e in restored_entitlements],
        "message": "Purchases successfully restored.",
    }


async def cancel_subscription_service(
    db: AsyncSession,
    learner_id: str,
    subscription_id: str,
    reason: str | None = None,
    settings: Settings | None = None,
) -> Subscription:
    sub = await db.get(Subscription, subscription_id)
    if not sub:
        raise APIError(404, "NOT_FOUND", "Subscription not found.")
    if sub.learner_id != learner_id:
        raise APIError(403, "FORBIDDEN", "You do not own this subscription.")
    cfg = settings or get_settings()
    if sub.provider != PaymentProvider.mock or cfg.environment not in {"development", "test"}:
        raise APIError(
            503,
            "PROVIDER_OPERATION_UNAVAILABLE",
            "Provider-native subscription cancellation is not configured.",
        )

    sub.cancel_at_period_end = True
    sub.cancellation_reason = reason or "User requested cancellation"
    await db.commit()
    return sub


async def change_subscription_plan_service(
    db: AsyncSession,
    learner_id: str,
    subscription_id: str,
    new_plan_id: str,
    proration_mode: str | None = None,
    settings: Settings | None = None,
) -> Subscription:
    sub = await db.get(Subscription, subscription_id)
    if not sub:
        raise APIError(404, "NOT_FOUND", "Subscription not found.")
    if sub.learner_id != learner_id:
        raise APIError(403, "FORBIDDEN", "You do not own this subscription.")
    cfg = settings or get_settings()
    if sub.provider != PaymentProvider.mock or cfg.environment not in {"development", "test"}:
        raise APIError(
            503,
            "PROVIDER_OPERATION_UNAVAILABLE",
            "Provider-native subscription plan changes are not configured.",
        )

    new_plan = await db.get(SubscriptionPlan, new_plan_id)
    if not new_plan or not new_plan.is_active:
        raise APIError(404, "NOT_FOUND", "Selected subscription plan not found.")

    current = now()
    period_days = 365 if new_plan.billing_interval == BillingInterval.annual else 30

    sub.plan_id = new_plan.id
    sub.tier = new_plan.tier
    sub.billing_interval = new_plan.billing_interval
    sub.current_period_end = current + timedelta(days=period_days)
    sub.renews_at = sub.current_period_end
    sub.cancel_at_period_end = False

    # Update active subscription entitlement
    entitlement = await db.scalar(
        select(Entitlement).where(
            Entitlement.subscription_id == sub.id,
            Entitlement.status == EntitlementStatus.active,
        )
    )
    if entitlement:
        entitlement.expires_at = sub.current_period_end
        meta = dict(entitlement.metadata_json or {})
        meta["planId"] = new_plan.id
        meta["tier"] = new_plan.tier.value
        entitlement.metadata_json = meta

    await db.commit()
    return sub


async def process_provider_webhook(
    db: AsyncSession,
    provider: str,
    headers: dict[str, str],
    body: bytes,
    settings: Settings | None = None,
) -> dict:
    cfg = settings or get_settings()
    verifier = get_payment_verifier(provider, cfg)

    # 1. Authenticity check & Event parsing
    event: ProviderWebhookEvent = await verifier.parse_and_verify_webhook(headers, body)

    if db.bind and db.bind.dialect.name == "postgresql":
        await db.execute(
            select(
                func.pg_advisory_xact_lock(
                    func.hashtextextended(f"webhook:{provider}:{event.event_id}", 0)
                )
            )
        )

    # 2. Idempotency on provider events
    try:
        provider_enum = PaymentProvider(provider)
    except ValueError as error:
        raise APIError(400, "UNSUPPORTED_PROVIDER", "Payment provider is not supported.") from error
    supported_event_types = {
        "RENEWAL",
        "DID_RENEW",
        "SUBSCRIPTION_RENEWED",
        "EXPIRATION",
        "EXPIRED",
        "SUBSCRIPTION_EXPIRED",
        "GRACE_PERIOD",
        "DID_FAIL_TO_RENEW",
        "IN_GRACE_PERIOD",
        "BILLING_RETRY",
        "BILLING_ISSUE",
        "CANCELLATION",
        "DID_CHANGE_RENEWAL_STATUS",
        "REFUND",
        "REVOCATION",
    }
    evt_type = event.event_type.upper()
    if evt_type not in supported_event_types:
        raise APIError(422, "UNSUPPORTED_PROVIDER_EVENT", "Unsupported provider event type.")
    existing_evt = await db.scalar(
        select(ProviderEvent).where(
            ProviderEvent.provider == provider_enum,
            ProviderEvent.event_id == event.event_id,
        )
    )
    if existing_evt:
        return {"status": "processed", "idempotent": True}

    evt_record = ProviderEvent(
        provider=provider_enum,
        event_id=event.event_id,
        event_type=event.event_type,
        payload_json=event.raw_payload,
        status=ProviderEventStatus.processed,
        occurred_at=event.effective_date,
        processed_at=now(),
    )
    db.add(evt_record)

    # 3. Find target subscription or purchase
    transaction_ids = {
        identifier
        for identifier in (event.original_transaction_id, event.provider_transaction_id)
        if identifier
    }
    subscriptions = (
        (
            await db.scalars(
                select(Subscription)
                .where(
                    Subscription.provider == provider_enum,
                    or_(
                        Subscription.original_transaction_id.in_(transaction_ids),
                        Subscription.latest_transaction_id.in_(transaction_ids),
                    ),
                )
                .with_for_update()
                .limit(2)
            )
        ).all()
        if transaction_ids
        else []
    )
    if len(subscriptions) > 1:
        raise APIError(
            409,
            "AMBIGUOUS_PROVIDER_TRANSACTION",
            "The provider event does not identify exactly one subscription.",
        )
    sub = subscriptions[0] if subscriptions else None

    if sub:
        last_provider_update = ensure_utc(sub.provider_state_updated_at)
        effective_date = ensure_utc(event.effective_date)
        if last_provider_update and effective_date and effective_date < last_provider_update:
            evt_record.status = ProviderEventStatus.ignored
            await db.commit()
            return {"status": "ignored", "eventId": event.event_id, "reason": "out_of_order"}

        sub.provider_state_updated_at = effective_date or now()
        if evt_type in ("RENEWAL", "DID_RENEW", "SUBSCRIPTION_RENEWED"):
            sub.status = SubscriptionStatus.active
            sub.current_period_end = event.expiration_date or (now() + timedelta(days=30))
            sub.renews_at = sub.current_period_end
            # Update entitlement
            ents = (
                await db.scalars(
                    select(Entitlement).where(
                        Entitlement.subscription_id == sub.id,
                    )
                )
            ).all()
            for ent in ents:
                ent.status = EntitlementStatus.active
                ent.expires_at = sub.current_period_end

        elif evt_type in ("EXPIRATION", "EXPIRED", "SUBSCRIPTION_EXPIRED"):
            sub.status = SubscriptionStatus.expired
            ents = (
                await db.scalars(
                    select(Entitlement).where(
                        Entitlement.subscription_id == sub.id,
                    )
                )
            ).all()
            for ent in ents:
                ent.status = EntitlementStatus.expired

        elif evt_type in ("GRACE_PERIOD", "DID_FAIL_TO_RENEW", "IN_GRACE_PERIOD"):
            sub.status = SubscriptionStatus.in_grace_period
            ents = (
                await db.scalars(
                    select(Entitlement).where(
                        Entitlement.subscription_id == sub.id,
                    )
                )
            ).all()
            for ent in ents:
                ent.status = EntitlementStatus.grace_period

        elif evt_type in ("BILLING_RETRY", "BILLING_ISSUE"):
            sub.status = SubscriptionStatus.billing_retry

        elif evt_type in ("CANCELLATION", "DID_CHANGE_RENEWAL_STATUS"):
            sub.cancel_at_period_end = True

        elif evt_type in ("REFUND", "REVOCATION"):
            sub.status = SubscriptionStatus.revoked
            ents = (
                await db.scalars(
                    select(Entitlement).where(
                        Entitlement.subscription_id == sub.id,
                    )
                )
            ).all()
            for ent in ents:
                ent.status = EntitlementStatus.revoked
                ent.revoked_at = now()

    else:
        # Check purchase
        purchase = await db.scalar(
            select(Purchase)
            .join(PaymentTransaction, Purchase.transaction_id == PaymentTransaction.id)
            .where(
                PaymentTransaction.provider == provider_enum,
                PaymentTransaction.provider_transaction_id.in_(
                    [event.provider_transaction_id, event.original_transaction_id]
                ),
            )
            .with_for_update()
        )
        if purchase and evt_type in ("REFUND", "REVOCATION"):
            purchase.status = PurchaseStatus.refunded
            entitlements = (
                await db.scalars(
                    select(Entitlement).where(
                        Entitlement.purchase_id == purchase.id,
                    )
                )
            ).all()
            for ent in entitlements:
                ent.status = EntitlementStatus.revoked
                ent.revoked_at = now()
        elif evt_type not in ("REFUND", "REVOCATION") or purchase is None:
            evt_record.status = ProviderEventStatus.ignored

    await db.commit()
    return {"status": "processed", "eventId": event.event_id}
