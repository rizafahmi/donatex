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
  - `{:error, reason}` — logs the failure with the donation id and a sanitized
    atom or changeset error list, leaves the queue untouched, replaces the
    alert DOM identity to restart its animation, and schedules another
    acknowledgement attempt after the new 8.5-second lifecycle.
- The donation remains `paid` / `alerted = false`, so the existing mount
  recovery path (`list_paid_unalerted_donations/0`) replays it after an overlay
  restart.

## Files
- `lib/donatex/donations.ex` — normalizes SQLite and connection failures during
  acknowledgement to `{:error, :persistence_failed}`.
- `lib/donatex_web/live/overlay_live.ex` — `require Logger`, pattern-match on
  `mark_donation_alerted_by_id/1` result, and visibly replay/retry the alert on
  error without advancing the queue.
- `test/donatex_web/live/overlay_live_test.exs` — regression test that uses a
  temporary SQLite trigger to reject the alerted update without deleting or
  changing the donation, asserts the current alert gets a fresh DOM lifecycle,
  the queued alert does not start, no `:donation_alerted` broadcast fires, and
  verifies the same `paid`/`alerted = false` row remains recoverable via
  `list_paid_unalerted_donations/0`; after removing the trigger, the retried
  acknowledgement succeeds and advances the queue.

## Verification
- 267 tests, 0 failures (`mix ci`) — #28-only branch (no unrelated #26 commit).
- Credo, Dialyzer, duplication, architecture: clean.
- Focused overlay suite (14 tests) passes; the warning log line confirms the
  error branch is exercised through a rejected persistence update.
