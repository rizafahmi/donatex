# ADR-007: Donation Lifecycle Invariants And Idempotent Transitions

## Status

Accepted

## Date

2026-05-01

## Context

Donatex persists donations in SQLite and relies on them for:

- Donor UX: a `pending` donation exists immediately after QR creation
- Webhook processing: duplicate deliveries are expected and must not break state
- Overlay recovery: the overlay loads `paid AND alerted = false` donations after restart
- Admin replay: operators can trigger a broadcast for missed alerts

The app must treat external input (donor form submissions and webhook payloads) as untrusted and enforce simple, stable donation invariants early so later LiveViews and webhook handlers can assume correct state.

## Decision

Adopt these invariants and API semantics in the donations context:

- Creation is always `pending` and `alerted = false` (`create_pending_donation/1` drops `status` and `alerted` from attrs)
- State transitions happen only via explicit context APIs
- `mark_paid_by_mayar_transaction_id/1` is idempotent (already paid returns `{:ok, donation}`)
- `mark_donation_alerted/1` is idempotent for already alerted donations and rejects invalid states (`{:error, :invalid_state}`)
- `mayar_transaction_id`, `donor_name`, and `message` are trimmed and constrained in length via the schema changeset
- The overlay recovery query is supported by a composite index for `status`, `alerted`, and `inserted_at`

## Alternatives Considered

### Allow callers to set status and alerted on create

- Pros: fewer functions and less ceremony
- Cons: invalid donation rows become easy to create; downstream code needs more defensive checks
- Rejected to keep lifecycle rules centralized and enforceable

### Treat repeated paid/alerted transitions as errors

- Pros: surfaces unexpected duplicates loudly
- Cons: webhook delivery is inherently at-least-once; treating duplicates as errors creates operational noise and complicates retry behavior
- Rejected to keep webhook processing simple and reliable

### Rely only on the unique index, without application-level validation

- Pros: less application code
- Cons: weak input quality guarantees for `donor_name` and `message`; error messages become less predictable
- Rejected to treat external input as untrusted and keep constraints explicit

## Consequences

- Webhook handlers can safely retry without introducing duplicate paid/alerted transitions.
- The overlay can recover missed alerts efficiently even as the donations table grows.
- Any introduction of new donation states beyond `pending | paid` should be recorded in a new ADR to avoid silent lifecycle drift.
