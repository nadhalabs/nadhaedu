# ADR 0004: Authentication and session boundaries

- Status: Accepted
- Date: 2026-08-31

## Context

Authentication spans untrusted form input, backend-specific payloads, sensitive tokens, persisted sessions, learner identity, navigation, refresh, and account lifecycle operations. Temporary network failures must not be confused with server-confirmed invalidation.

## Decision

Keep backend structures in DTOs and map them to token-free domain session metadata. Persist access and refresh material only through `SecureStore`. Centralize session transitions in `AuthController`, and let the repository decide when persistence changes. Clear secure state only after explicit logout/deletion or confirmed unauthorized responses. Model external providers and OTP as capabilities so unavailable methods are not presented.

Use a deterministic in-memory source only for development and tests. Staging and production fail closed until a production server adapter is composed.

## Consequences

UI code cannot access tokens, temporary outages preserve recoverable session material, and backend/vendor integration remains replaceable. Client redirects are not authorization; every protected server operation still requires server-side enforcement and revocation checks.
