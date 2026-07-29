# ADR-010: Drop Redundant Donation Lookup Index

## Status

Accepted

## Date

2026-05-02

## Context

Notable uses a SQLite-backed `donations` table. The overlay recovery query filters and orders by:

- `status = "paid"`
- `alerted = false`
- `inserted_at ASC, id ASC`

Two composite indexes existed to support parts of this access pattern:

- `index(:donations, [:status, :alerted, :inserted_at])` (migration `AddDonationsLookupIndexes`)
- `index(:donations, [:status, :alerted, :inserted_at, :id], name: :donations_recovery_queue_idx)` (migration `AddDonationQueryIndexes`)

The second index is a strict superset of the first. Keeping both increases write amplification and database size without improving query planning for the recovery query.

## Decision

Drop the redundant smaller index and keep `donations_recovery_queue_idx` as the single recovery-focused index.

Implemented via migration `DropRedundantDonationIndex`.

## Alternatives Considered

### Keep both indexes

- Pros: no migration required
- Cons: extra index maintenance on every insert/update; larger DB; higher write cost
- Rejected because the indexes overlap and do not provide distinct value

### Drop the larger index instead

- Pros: smaller index footprint
- Cons: recovery ordering would lose `id` in-index ordering and may regress worst-case planning as data grows
- Rejected because the recovery query is a core path and should stay fully covered

## Consequences

- Lower write cost for donation inserts/updates compared to maintaining two overlapping indexes.
- Slightly simpler schema to reason about when tuning queries.
- If future query patterns require different indexes, add purpose-built indexes rather than accumulating partial overlaps.

