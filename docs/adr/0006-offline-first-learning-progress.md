# ADR 0006: Offline-first learning progress with authoritative reconciliation

## Status

Accepted

## Context

Playback emits frequent position changes, learners may use several devices, and connectivity can disappear during a lesson. Sending every tick would waste battery and network capacity, while accepting client course totals as authority would create integrity and access-control problems.

## Decision

The client records bounded position checkpoints and explicit completion changes as durable, idempotently identified mutations. It updates a learner-isolated local projection immediately and batches synchronization on a 30-second throttle and lifecycle boundaries.

The server owns revisions and the accepted snapshot. A synchronization response includes its authoritative course snapshot and the mutation IDs it accepted or had already processed. The client removes only acknowledged mutations, then replays any remaining mutations in event order over the returned server snapshot. Local history and pending outbox sizes are bounded.

Course structure is indexed once per loaded course. Navigation uses lesson ID indexes; course progress derives from the indexed outline when progress changes rather than rescanning nested modules during every widget build.

Playback sources come from an authenticated service boundary. Only HTTPS HLS is accepted by the player. Production servers are responsible for authorization, short-lived signed manifests, subtitle metadata, and revocation; a client route is never an entitlement control.

## Consequences

- Temporary offline progress survives restarts and is visible immediately.
- Duplicate batch delivery is safe when the server deduplicates mutation IDs.
- Cross-device changes converge on the latest server snapshot without discarding still-pending local work.
- The outbox cap protects client storage. A production service should monitor repeated failures before the cap is approached.
- Manual adaptive-track selection requires a later compatible SDK/plugin upgrade; current native players select HLS renditions adaptively.
