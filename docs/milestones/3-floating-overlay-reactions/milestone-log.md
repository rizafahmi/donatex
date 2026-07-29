# Milestone 3 — Floating Overlay Reactions

## What's new in the app

- Free Notes now produce ephemeral emoji floats on `/overlay`
- Each float picks a random emoji from the Note’s reaction pool and shows no sender or message
- Multiple free floats can appear at the same time and fade out after a few seconds
- Paid tip celebrations remain sequential with sound, confetti, recovery, and replay
- Pending tip creation and overlay reloads do not spawn free floats

## What was built

### Reaction pools

- `Notable.Reactions` with pools:
  - bad: 😅 🫠 💤 🙈
  - ok: 😐 🤔 😶 🫤
  - good: 😊 👍 🙌 💪
  - great: 🤩 🔥 🎉 ⭐
- `pool/1` and `pick_emoji/1` for overlay float selection

### Overlay floats (`OverlayLive`)

- Subscribes to `donations:created` in addition to `donations:paid`
- Spawns floats only for `status == "sent"` free Notes
- Stores floats in `:floats` map keyed by donation id
- Randomizes start X, horizontal drift, and duration (3000–4000 ms)
- Removes each float via `Process.send_after` → `{:dismiss_float, id}`
- Renders emoji-only nodes (no donor name / message)
- Tip queue, dismiss, mark-alerted, recovery, and replay paths unchanged

### CSS

- `.obs-float-emoji` + `@keyframes obs-float-path` driven by `--float-start-x`, `--float-drift-x`, `--float-duration`
- Float z-index stays below the tip terminal alert

### Key tests

- `test/notable/reactions_test.exs` — pool membership and pick behavior
- `test/notable_web/live/overlay_live_test.exs` — emoji-only float, pending ignored, multi-float, dismiss, no tip celebration, no mount recovery

## Unspecified implementation decisions

- CSS + LiveView assigns (no JS hook) for float motion
- Float id equals donation id (one float per free Note)
- Duration randomly chosen in 3000–4000 ms to match the PRD window
- Pending tip rows on `donations:created` are ignored rather than introducing a dedicated free-Note topic

## What the next milestone needs to know

- Milestone 4 (Optional Appreciation Experience) can redesign the donor form without changing overlay float plumbing
- Overlay already consumes free Notes from `donations:created`; tip celebrations stay on `donations:paid`
- Free Notes remain `alerted: true` at insert and have no recovery/replay path by design

## PRD deviations

- None for Milestone 3 scope

## Verification

- `mix test` — 105 tests, 0 failures (2026-07-16)
- Done when checks:
  - Free Notes produce simultaneous emoji-only floats that vanish within 3–4 seconds
  - Confirmed tips still use the existing queued celebration only
  - Overlay reload does not recover free reactions
