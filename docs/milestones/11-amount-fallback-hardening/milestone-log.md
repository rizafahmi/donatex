# Milestone 11 — Amount-Fallback Payment Correlation Hardening

**Issue:** [#26](https://github.com/rizafahmi/donatex/issues/26) — Harden amount-fallback payment correlation
**Status:** Implementation complete; pending review
**Blocked by:** #25 (merged on main via PR #34)

## Goal

Make amount-based Mayar webhook fallback correlation atomic and fail-closed when multiple pending tips share the same amount (unless identity is unambiguous via donor_name).

## What changed

### `lib/donatex/donations.ex`
- Replaced `get_pending_donation_by_amount/2` (returned oldest match via `LIMIT 1`) and `count_pending_by_amount/1` with `claim_pending_by_amount/3`
- `claim_pending_by_amount/3` runs inside `Repo.transaction`: counts all pending tips matching amount (+ optional donor_name); if exactly one, atomically remaps `mayar_transaction_id` and sets `status = "paid"` in a single `UPDATE ... WHERE status = 'pending'`; if zero, rolls back `:not_found`; if more than one, rolls back `:ambiguous` (fail closed)
- Returns `{:ok, donation, changed?}` or `{:error, :ambiguous | :not_found | :invalid_state}`

### `lib/donatex_web/controllers/mayar_webhook_controller.ex`
- Replaced `find_by_amount_fallback/1` (which returned a single donation + logged a warning but still claimed it) with a `:amount_fallback` sentinel
- `handle_donation_match(:amount_fallback, ...)` now calls `claim_pending_by_amount/3` directly and handles all outcomes: broadcast on unique claim, log + no-op on ambiguous, log orphan on not_found
- Extracted `broadcast_paid/2` from `mark_donation_paid` to share between exact-match and fallback paths
- Removed dead code: `find_by_amount_fallback/1`

### Tests
- `test/donatex/donations_test.exs` — 6 new `claim_pending_by_amount/3` tests: unique claim, ambiguous fail-closed, donor_name disambiguation, orphan, same-name ambiguous, already-paid no-claim
- `test/donatex_web/controllers/mayar_webhook_controller_test.exs` — 3 new integration tests: ambiguous fail-closed (no paid mark, no broadcast), donor_name disambiguation via webhook, orphan payment

## Verification
- `mix test` — 272 tests, 0 failures
- `mix credo --strict` — 0 issues
- `mix dialyzer` — 0 errors
- `mix compile --warnings-as-errors` — clean

## Acceptance criteria
- [x] Claiming a pending tip by amount (+ optional donor name) is a single transactional operation with the paid transition
- [x] When more than one pending tip matches the amount ambiguously, the system fails closed (no paid mark / no alert) unless disambiguation succeeds
- [x] Edge-case tests cover: multi-pending same amount, orphan payment (no match), donor_name disambiguation, and failed transaction-id update (now atomic — no separate update step)
- [x] Successful unique fallback still marks paid, persists, then broadcasts once
