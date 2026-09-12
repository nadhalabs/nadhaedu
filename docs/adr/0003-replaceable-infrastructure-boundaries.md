# ADR 0003: Replaceable infrastructure boundaries

- Status: Accepted
- Date: 2026-08-31

## Context

Networking, storage, observability, and connectivity vendors evolve and have different platform constraints.

## Decision

Application-owned interfaces define API access, local persistence, secure storage, connectivity, analytics, crash reporting, and logging. Bootstrap selects concrete adapters. Analytics and crash reporting remain no-op until privacy requirements and a vendor are approved.

## Consequences

Vendor migration is localized and tests can use deterministic fakes. Interfaces must remain capability-focused rather than mirroring vendor SDKs.
