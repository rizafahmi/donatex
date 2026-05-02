# ADR-018: Fail Closed When QR Is Created But Donation Persistence Fails

## Status

Accepted

## Date

2026-05-02

## Context

The donor flow creates a Mayar dynamic QR and then persists a local `pending` donation row keyed by `mayar_transaction_id`.

Because the QR creation request is an external side effect, it can succeed while the DB insert fails (for example: validation, unique constraints, SQLite write failures).

If the donor is shown a QR code whose `mayar_transaction_id` is not persisted, then a later `payment.received` webhook cannot be correlated and the system cannot reliably:

- mark the donation as paid
- broadcast to the overlay
- recover missed alerts after restarts
- dedupe retries based on `mayar_transaction_id`

The MVP must prefer correct accounting and recoverability over “always show a QR”.

## Decision

If Mayar QR creation succeeds but persisting the pending donation fails:

1. Do not render the QR to the donor.
2. Keep the donor on the form screen and show an error message asking them to retry.
3. Warn the donor not to complete payment if they already scanned the QR code.
4. Log an operational warning containing:
   - `mayar_transaction_id`
   - amount
   - changeset error summary
   The log must not include the QR URL (or donor message) to reduce sensitive leakage.

## Alternatives Considered

### Persist donation first, then create QR

- Pros: never creates an “orphan” Mayar transaction without a local donation row
- Cons: creates local pending rows when Mayar QR creation fails; requires cleanup policy for never-used rows
- Rejected for now; it introduces a new operational concern (cleanup/retry semantics) without improving correctness for the current invariant (“donations are keyed by Mayar transaction id”)

### Show the QR even if persistence fails and rely on webhooks only

- Pros: donor experience continues without interruption
- Cons: breaks the system’s durability and correlation guarantees; paid donations may never alert; dedupe cannot work without a stored transaction id
- Rejected; correctness and recoverability are more important for MVP

### Attempt to cancel or invalidate the Mayar transaction

- Pros: would reduce the chance of paid-but-untracked transactions
- Cons: not supported/guaranteed by the documented Mayar API; introduces a second external side effect with its own failure modes
- Rejected for MVP

## Consequences

- The donor flow fails closed when the system cannot persist a pending donation, even if Mayar already created a QR.
- In rare cases, a donor could still complete payment after scanning a QR; the webhook will be ignored because the donation row does not exist.
- Operational visibility is improved via targeted warning logs that are safe to keep.

