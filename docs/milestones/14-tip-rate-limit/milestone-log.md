# Milestone 14 — Tip Path Rate Limit & Orphan QRIS Fail-Closed

**Issue**: [#27](https://github.com/rizafahmi/donatex/issues/27)
**Status**: Complete

## Goal

Rate-limit tip → Mayar QRIS creation (same `SubmissionLimiter` pattern as free feedback) before calling Mayar, and keep the existing fail-closed donor experience when Mayar succeeds but local pending persist fails.

## What changed

### `lib/donatex_web/live/donate_live.ex`

1. **Tip rate limit before Mayar (AC1)**: `create_tip_or_assign_error/2` reserves `SubmissionLimiter.reserve({:tip, ip})` before `create_pending_donation_with_qr/1`. On `{:error, :rate_limited}`, flashes the Indonesian cooldown copy, clears `:tip_submitting`, and stays on the form.
2. **Keep reservation after Mayar attempt**: Success, Mayar failure, and persist failure all keep the tip slot so the same IP cannot spam create_qr / orphan QRIS within the 10s window.
3. **Persist fail-closed (AC2)**: Existing path unchanged — flash “Tip belum bisa disimpan…”, no payment step / QR assign, no local pending row.

### Tests

- New `test/donatex_web/live/donate_live_tip_rate_limit_test.exs` — second tip from same IP within 10s does not call Mayar again.
- `donor_qr_flow_test` / `donate_live_tip_hardening_test` reset `SubmissionLimiter` in setup (PhoenixTest tips share peer IP).
- `submission_limiter_test` asserts `{:tip, ip}` is independent of feedback/question namespaces.

## Verification

- Focused tip/feedback/donor QR suites: 15 tests, 0 failures
- `mix ci`: 267 tests, 0 failures; Credo/Dialyzer/ex_dna/reach OK
