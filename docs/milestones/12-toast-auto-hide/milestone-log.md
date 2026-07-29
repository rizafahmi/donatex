# Milestone 12 — Toast Auto-Hide (#39)

## Issue
[#39 — Hide toast/notif after some time](https://github.com/rizafahmi/notable/issues/39)

After submitting the `/questions` form, the success/error toast persisted
indefinitely instead of dismissing after a few seconds. Root cause: the shared
`CoreComponents.flash/1` component only cleared on click (`phx-click` →
`lv:clear-flash`) with no auto-dismiss timer.

## Fix
- Added a `FlashAutoHide` JS hook (`assets/js/app.js`) that pushes
  `lv:clear-flash` after 5 s.
- Wired the hook into the shared `flash/1` component via a new `auto_hide`
  attr (default `true`) plus `data-flash-key`.
- Added per-kind server-side flash generations so every `put_flash/3`, including
  an identical repeated message, resets the matching hook's timer.
- Connection-error toasts (`client-error` / `server-error`) opt out with
  `auto_hide={false}` since they are managed by `phx-connected` /
  `phx-disconnected`.

## Files
- `assets/js/app.js` — `FlashAutoHide` hook
- `lib/notable_web/components/core_components.ex` — `auto_hide` attr + hook wiring
- `lib/notable_web/components/layouts.ex` — `auto_hide={false}` on connection toasts
- `test/notable_web/live/question_live_test.exs` — hook presence + opt-out tests

## Verification
- 274 tests, 0 failures
- Credo, Dialyzer, duplication, architecture: clean
- Browser smoke pending (JS hook behaviour requires a live client)
