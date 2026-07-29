# ADR-006: Donations Table Schema

## Status

Accepted

## Date

2026-05-01

## Context

Notable needs a durable `donations` table in SQLite that supports:

- Creating a local donation row at QR generation time (`pending` state)
- Upgrading that same row to `paid` after webhook confirmation
- Deduplicating webhook deliveries by Mayar transaction identifier
- Overlay recovery by querying `paid AND alerted = false`
- A minimal admin list and replay control surface

The schema must be stable early because it becomes the backbone for Mayar integration, LiveView flows, and overlay behavior.

## Decision

Create a `donations` table with:

- `id` as `:binary_id` primary key (UUID)
- `mayar_transaction_id` as required string with a unique index
- `donor_name` as required string
- `amount` as required integer (IDR)
- `message` as optional text
- `status` as required string with default `"pending"` (allowed values will be enforced in the schema changeset)
- `alerted` as required boolean with default `false`
- `inserted_at` / `updated_at` timestamps in UTC

## Alternatives Considered

### Use integer autoincrement primary key

- Pros: simpler to read, slightly smaller storage
- Cons: leaks row ordering, harder to merge/import across environments, less consistent with Phoenix generators using `binary_id`
- Rejected because the project is already configured for `binary_id` primary keys and we want stable IDs across all entities

### Use an enum type for status

- Pros: stronger constraints at the DB level
- Cons: SQLite support for enums is not native; would still require CHECK constraints or application-level validation
- Rejected because we can get equivalent correctness with schema validations and keep migrations simple for SQLite

### Store `alerted` as part of `status` (e.g. `pending | paid | alerted`)

- Pros: fewer columns
- Cons: mixes payment lifecycle with overlay acknowledgement semantics; makes `paid-but-not-alerted` recovery queries less explicit
- Rejected to keep payment state and overlay acknowledgement state separate

## Consequences

- Webhook idempotency is enforced by the unique index on `mayar_transaction_id`.
- Overlay recovery remains a simple query: `status = "paid" AND alerted = false`.
- Any additional donation lifecycle states beyond `pending | paid` should be introduced via a new ADR to avoid silent schema drift.

