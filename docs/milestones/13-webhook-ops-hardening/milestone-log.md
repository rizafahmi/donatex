# Milestone 13 — Webhook Ops Hardening

**Issue**: [#31](https://github.com/rizafahmi/donatex/issues/31)
**Status**: Complete

## Goal

Harden the Mayar webhook controller for production reliability: return retryable HTTP 500 on transient DB failures, narrow the bare rescue so programmer errors propagate, and align webhook payload log redaction with ADR-017.

## What changed

### `lib/donatex_web/controllers/mayar_webhook_controller.ex`

1. **Retryable failure on persist errors (AC1)**: `mark_donation_paid/2` and `update_transaction_id_and_mark_paid/2` now return `{:error, reason}` instead of `:ok` on DB failures. `create/2` threads the error and returns HTTP 500 with `%{"ok" => false}` so Mayar can retry.

2. **Narrow rescue (AC2)**: `lookup_original_transaction_id/1` rescue narrowed from bare `rescue _` to `rescue e in Req.TransportError`. Programmer errors propagate instead of being silently converted to amount-fallback.

3. **Log redaction (AC3)**: `redacted_webhook_payload/1` now redacts any key containing "qr" via `redact_qr_keys/1` plus known URL keys via `redact_url_keys/1`, consistent with ADR-017. Previously only 3 hardcoded keys were dropped.

4. **Non-retryable inputs unchanged (AC4)**: malformed payloads and orphan payments remain acknowledged with HTTP 200 rather than requesting a retry.

### `test/donatex_web/controllers/mayar_webhook_controller_test.exs`

6 new test cases cover all four acceptance criteria.

## Verification

- `mix ci`: 271 tests, 0 failures, Credo clean, Dialyzer clean, no duplication, architecture OK
