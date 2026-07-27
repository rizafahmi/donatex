# Milestone 13 — Overlay Alert Persistence (#28)

## Issue
[#28 — Overlay: advance queue only after alerted persist succeeds](https://github.com/rizafahmi/donatex/issues/28)

The OBS overlay cleared the current tip alert and advanced the queue
unconditionally on `:dismiss_current`, even when
`Donations.mark_donation_alerted_by_id/1` failed. A failed acknowledgement
dropped the alert from the in-memory queue as if it had been acknowledged, so
the tip would never replay on remount recovery and could loop forever.

## Fix
- `handle_info({:dismiss_current, id}, socket)` now matches on the result of
  `mark_donation_alerted_by_id/1`:
  - `{:ok, donation}` — broadcasts `:donation_alerted`, clears `current`, and
    starts the next queued alert (unchanged happy path).
  - `{:error, reason}` — logs the failure with the donation id and reason
    (no donor message or payment URL), and leaves `current` and the queue
    untouched so the alert stays rendered and sequential delivery is preserved.
- The donation remains `paid` / `alerted = false`, so the existing mount
  recovery path (`list_paid_unalerted_donations/0`) replays it after an overlay
  restart.

## Files
- `lib/donatex_web/live/overlay_live.ex` — `require Logger`, pattern-match on
  `mark_donation_alerted_by_id/1` result, keep alert on error.
- `test/donatex_web/live/overlay_live_test.exs` — regression test that forces an
  acknowledgement failure by deleting the donation row (so
  `mark_donation_alerted_by_id/1` returns `{:error, :not_found}`), asserts the
  current alert stays rendered, the queued alert does not start, no
  `:donation_alerted` broadcast fires for the donation's id (matched on `id`
  alone so a success payload with `alerted: true` would still be caught), and
  verifies a `paid`/`alerted = false` row remains recoverable via
  `list_paid_unalerted_donations/0`.

## Verification
- 267 tests, 0 failures (`mix ci`) — #28-only branch (no unrelated #26 commit).
- Credo, Dialyzer, duplication, architecture: clean.
- Focused overlay suite (14 tests) passes; the warning log line confirms the
  error branch is exercised (`:not_found` failure seam).
