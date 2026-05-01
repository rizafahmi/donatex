# ADR-009: Add A Composite Index For Overlay Recovery Queries

## Status

Accepted

## Date

2026-05-01

## Context

The OBS overlay must recover missed alerts after restart by loading persisted donations where:

- `status = "paid"`
- `alerted = false`

and then presenting those alerts in a stable order:

- `inserted_at ASC, id ASC`

As the donations table grows, this query becomes a frequent read path (overlay mount, potentially multiple times during development and production restarts). Without an index, SQLite will need to scan and sort more rows as data grows.

## Decision

Add a composite index covering:

- filter columns: `status`, `alerted`
- ordering columns: `inserted_at`, `id`

Implemented via migration `AddDonationQueryIndexes` as `donations_recovery_queue_idx`.

## Alternatives Considered

### Rely on the unique index only (`mayar_transaction_id`)

- Pros: no extra index maintenance
- Cons: does not help the recovery query; still requires scanning/sorting
- Rejected because it optimizes a different access pattern (webhook dedupe)

### Add separate indexes on `(status, alerted)` and `(inserted_at, id)`

- Pros: smaller individual indexes
- Cons: less effective for the combined filter + order query; may still require extra work to merge results
- Rejected in favor of a single purpose-built index for the recovery query

### Do nothing until performance is an issue

- Pros: less schema churn early
- Cons: recovery performance degradation is predictable with table growth; adding the index later still requires a migration
- Rejected because this is a low-risk, high-leverage optimization for a core path

## Consequences

- Overlay recovery should remain fast as donations volume increases.
- Writes incur a small additional cost to maintain the new index.
- If the recovery query changes materially, revisit this index (or add a new one) rather than accumulating unused indexes.
