# ADR 0005: Server-driven catalog discovery

- Status: Accepted
- Date: 2026-08-31

## Context

Course catalogs and personalized home feeds can grow beyond client memory and evolve independently of app releases. Search, filters, ranking, bookmarks, and recent activity need consistent cross-device behavior.

## Decision

Represent catalog requests as bounded queries with opaque cursors. Perform search, filtering, sorting, and feed ordering behind the data-source boundary. Model Home as an ordered list of typed server sections. Cache pages by complete query key, deduplicate appended pages by course ID, and mark cached responses. Use server-facing bookmark and recently-viewed contracts with bounded local fallback indexes.

Use builder-based slivers/grids and debounce search input. Keep recommendation generation server-side; the client renders supplied sections only. Use a deterministic bounded source for development and fail closed in staging/production until the real API adapter exists.

## Consequences

The client never requires a full catalog download, new feed arrangements do not require routing changes, and recommendation systems can evolve independently. Real API integration must preserve cursor opacity, authorization, cache invalidation, and cross-device synchronization.
