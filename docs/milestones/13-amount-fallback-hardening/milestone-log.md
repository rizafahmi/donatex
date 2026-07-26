# Milestone 13 — Amount-Fallback Payment Correlation Hardening (#26)

## Issue
[#26 — Harden amount-fallback payment correlation](https://github.com/rizafahmi/donatex/issues/26)

When Mayar sends a confirmation transaction ID that differs from the QR
transaction ID, the webhook controller fell back to matching by amount. The
previous implementation had two problems:

1. **Non-atomic two-step**: `update_mayar_transaction_id/2` then
   `mark_paid_with_change/1` were separate operations — a crash or race
   between them could leave an orphaned state (tx_id updated but not paid).
2. **No fail-closed on ambiguity**: When multiple pending donations shared
   the same amount, the controller logged a warning but still picked the
   newest one, risking remapped correlation under concurrent same-amount
   payments.

## Fix

### Donations context (`lib/donatex/donations.ex`)

- **`claim_pending_by_amount_with_change/3`** — Atomically claims a pending
  donation by amount (+ optional `donor_name`) and sets the new Mayar
  transaction ID in a single `UPDATE … WHERE status = 'pending'` statement.
  Fails closed with `{:error, :ambiguous}` when more than one pending
  donation matches, preventing remapped correlation. Returns
  `{:error, :not_found}` for orphan payments.

- **`claim_with_transaction_id_update/2`** — Atomically updates the
  transaction ID and marks paid for a known donation (used by the Mayar
  original-transaction-id lookup path). Replaces the non-atomic
  `update_mayar_transaction_id/2` + `mark_paid_with_change/1` two-step.

- **`paid_claim_result/1`** (private) — Extracted shared recovery pattern
  for the `UPDATE … WHERE status = 'pending'` 0-row case, eliminating the
  ExDNA code clone between `mark_paid_with_change/1` and
  `claim_with_transaction_id_update/2`.

- Removed `get_pending_donation_by_amount/2`, `count_pending_by_amount/1`,
  and `update_mayar_transaction_id/2` — dead code after the refactor.

### Webhook controller (`lib/donatex_web/controllers/mayar_webhook_controller.ex`)

- The amount-fallback path now returns an `:amount_fallback` signal instead
  of a pre-selected donation. `handle_donation_match/2` calls
  `claim_by_amount_fallback/1` which delegates to the atomic
  `claim_pending_by_amount_with_change/3`.

- The Mayar lookup path now uses `claim_and_broadcast/3` which delegates to
  the atomic `claim_with_transaction_id_update/2`.

- Removed `find_by_amount_fallback/1` and
  `update_transaction_id_and_mark_paid/2` — replaced by the atomic
  functions above.

## Tests

### `test/donatex/donations_test.exs`
- `claim_pending_by_amount_with_change/3`:
  - Atomically claims the single matching pending donation by amount
  - Fails closed when multiple pending donations share the same amount
  - Disambiguates by donor_name when only one matches
  - Returns not_found for orphan payment with no matching amount
  - Returns not_found after the donation is already claimed (idempotency via exact match)
  - Fails closed when same amount + same donor_name has multiple pending
- `claim_with_transaction_id_update/2`:
  - Atomically updates transaction id and marks paid
  - Returns false for already-paid donation
  - Claims at most once under concurrent calls (12 Task.async)

### `test/donatex_web/controllers/mayar_webhook_controller_test.exs`
- Amount fallback fails closed when multiple pending donations share the same amount
- Amount fallback disambiguates by donor_name
- Amount fallback logs orphan payment when no donation matches
- Amount fallback claims the unique pending donation and broadcasts once (with duplicate delivery)

## Verification
- 279 tests, 0 failures
- Credo, Dialyzer, ExDNA duplication, architecture: clean (`mix ci`)
