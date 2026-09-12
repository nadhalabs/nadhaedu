# ADR 0001: Feature-first layered architecture

- Status: Accepted
- Date: 2026-08-31

## Context

The application must scale across multiple product areas and teams without coupling business concepts to Flutter widgets or vendors.

## Decision

Organize product code by feature, with presentation, application, domain, and data boundaries inside each feature. Keep shared capabilities small and place composition in bootstrap. Dependencies point toward domain/application contracts.

## Consequences

Features remain independently testable and vendor implementations remain replaceable. The structure adds a small amount of ceremony, so a layer is created only when it owns real behavior.
