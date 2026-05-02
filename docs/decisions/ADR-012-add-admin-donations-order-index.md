# ADR-012: Add An Index For Donation Ordering Queries

## Status

Accepted

## Date

2026-05-02

## Context

Donatex frequently needs to load donations in a stable chronological order for operator-facing views, including the admin donation list:

- `inserted_at ASC, id ASC`

As the donations table grows, SQLite may need to sort a large number of rows when no suitable index exists to satisfy the ordering.

## Decision

Add an index on:

- `inserted_at`
- `id`

implemented via migration `AddDonationsOrderIndex` as `donations_order_idx`.

## Alternatives Considered

### Reuse the overlay recovery index (`donations_recovery_queue_idx`)

- Pros: no additional index maintenance
- Cons: the recovery index is keyed by `status` and `alerted` first, so it does not help a general-purpose ordering query without those filters
- Rejected because it optimizes a different access pattern

### Index `inserted_at` only

- Pros: smaller index footprint
- Cons: does not fully cover the ordering stability guarantee (`id` tie-break) and can still require extra work for consistent ordering
- Rejected in favor of keeping the full ordering columns in-index

### Do nothing until performance becomes an issue

- Pros: less schema churn early
- Cons: the sort cost grows predictably with data volume and is a common path for admin usage
- Rejected as a low-risk preventative optimization

## Consequences

- Admin donation lists can read donations in a stable order with less sorting work as the table grows.
- Inserts pay a small additional cost to maintain the new index.
