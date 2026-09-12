# ADR 0007: Freemium access policy inheritance and server-authoritative entitlements

## Status

Accepted

## Context

The learning platform provides varied access models, including free courses, premium subscription tiers, individual course purchases, bundled catalog collections, promotional grants, coupon redemptions, educational scholarships, time-limited trial passes, and administrative overrides. 

A single boolean flag or naive client-only check cannot support hierarchical overrides (Course → Module → Lesson), multiple simultaneous entitlement sources, or authoritative security boundaries. Furthermore, presentation layers should consume consistent, typed access decisions rather than reproducing entitlement logic across UI widgets.

## Decision

1. **Typed Domain Models**:
   - `ResourceType`: Typed enum covering courses, modules, lessons, quizzes, resources, and certificates.
   - `EntitlementStatus`: `active`, `expired`, `revoked`, `pending`, `gracePeriod`.
   - `EntitlementSource`: Sealed hierarchy for subscriptions, individual purchases, bundles, promotions, trials, coupons, scholarships, time-limited access, and administrative grants.
   - `AccessPolicy`: Configurable policy supporting `free`, `premium`, `preview`, `inherit`, and `unavailable`, with optional subscription-tier and bundle constraints.
   - `AccessDecision`: Typed evaluation result containing access state (`free`, `preview`, `locked`, `included`, `purchased`, `subscribed`, `expired`, `unavailable`), access reason, winning entitlement, and stale indicator.

2. **Hierarchical Policy Resolution**:
   Access policies cascade via `AccessPolicy.resolve(coursePolicy, modulePolicy, lessonPolicy)`:
   `Course Access Policy` → `Section / Module Override` (when configured) → `Lesson / Resource Override` (when configured).

3. **Centralized Evaluation & Multi-Source Precedence**:
   `AccessEvaluator` centralizes deterministic evaluation. When a learner possesses multiple active entitlement sources, precedence is resolved deterministically:
   `Administrative Grant` > `Scholarship` > `Individual Purchase` > `Bundle` > `Subscription` > `Promotion` > `Coupon` > `Trial` > `Time-Limited Access`.

4. **Authoritative Backend Security Boundary**:
   Local client storage caches learner-isolated entitlements for responsive offline-first UX and optimistic evaluation. Cache provenance remains marked stale through repository and controller state. However, protected remote content and media playback streams (`fetchPlaybackSource`) are strictly verified against server-owned resource metadata. Client-side state tampering cannot bypass server access control. Missing production configuration fails closed and never selects the development adapter.

5. **Reusable Presentation & Accessibility**:
   Reusable `AccessStatusBadge` and `AccessGateView` components present accessible, high-contrast, semantic-rich UI states across all 8 freemium states.

## Consequences

- Presentation code cleanly subscribes to `accessDecisionProvider` without duplicating entitlement rules.
- Multiple simultaneous entitlement sources resolve deterministically with auditable rationale.
- Offline and cached states are explicitly flagged as stale (`isStale: true`) without compromising server authority.
- Tier and bundle constraints apply to matching subscription/trial and bundle sources; purchases and explicit grants remain independent acquisition paths when they cover the resource.
