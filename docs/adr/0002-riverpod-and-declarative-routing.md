# ADR 0002: Riverpod and declarative routing

- Status: Accepted
- Date: 2026-08-31

## Context

The foundation needs explicit dependency injection, test overrides, state ownership, deep links, and browser-compatible navigation.

## Decision

Use Riverpod providers as the dependency/state graph and `go_router` as the declarative routing boundary. Routers and vendor adapters are created through providers at the composition root.

## Consequences

Tests can replace dependencies without service locators, and navigation is URL-first. Route guards will be added only with real authentication/authorization flows; the server remains authoritative.
