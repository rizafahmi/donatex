# ADR-016: Require Paid Status And Amount Match For Webhook Processing

## Status

Accepted

## Date

2026-05-02

## Context

Donatex uses Mayar webhooks to transition persisted donations from `pending` to `paid`, then broadcasts `donations:paid` for the donor page and overlay.

Mayar webhook authenticity for the MVP is based on a tokenized callback URL (ADR-008). This protects the endpoint from casual guessing but does not prove payload integrity.

To reduce risk of false-positive `paid` transitions (whether from malformed payloads, upstream changes, or abuse), webhook processing should validate that the payload is consistent with an existing persisted donation row.

## Decision

Treat a webhook payload as eligible for payment confirmation only when:

1. `event == "payment.received"`
2. `transactionStatus` (or fallback `status`) is `paid`
3. The referenced `transactionId` (or fallback `id`) resolves to an existing donation by exact local ID, a Mayar lookup of the original QR transaction ID, or one unique pending amount/name match
4. The webhook `amount` matches the stored donation amount

The amount/name fallback fails closed when no candidate or multiple candidates match. Claiming a fallback candidate updates its Mayar transaction ID and status in one conditional database write, so concurrent webhook deliveries cannot claim or broadcast the same pending donation twice.

If any condition fails, the webhook request is safely ignored (no state change, no broadcast) while still returning a successful response for authenticated requests.

## Alternatives Considered

### Accept any `payment.received` event and mark paid without further validation

- Pros: simplest implementation
- Cons: increases chance of marking the wrong donation as paid if payloads are malformed or abused; does not leverage the fact that Donatex already has an expected amount stored at QR creation time
- Rejected to keep the webhook path resilient under untrusted input

### Validate only `transactionStatus == paid`

- Pros: low effort while rejecting obvious non-paid updates
- Cons: still allows mismatched payloads to transition state when a transaction id is known; amount mismatch would still mark paid
- Rejected to keep correlation checks stronger while still staying simple

## Consequences

- Webhook processing becomes stricter and reduces false-positive transitions.
- Legitimate confirmations that cannot be uniquely correlated remain pending for operational review instead of being guessed by recency.
- If Mayar changes the meaning or format of `amount`, Donatex may ignore legitimate paid deliveries until the mapping is confirmed and updated.
- This complements (but does not replace) the need for an official Mayar signing mechanism when available (ADR-008).
