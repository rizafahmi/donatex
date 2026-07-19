# Milestone 9 — Donor Visitor Presence

## Outcome

- The public donor page now counts active anonymous browser sessions with Phoenix Presence.
- Multiple tabs sharing one signed browser session count as one visitor.
- A subdued `N orang sedang di halaman ini` indicator appears only at three or more visitors and updates after joins and leaves.
- Presence identity is a random 16-byte URL-safe value stored only in the signed session. No IP address, user-agent, donor value, fingerprint, database row, or historical visitor record is used.
- Presence setup failures leave the optional indicator hidden without making the donor form unavailable.
- Review follow-up: track/list failures now disable further Presence refreshes (unsubscribe + ignore diffs), narrowly catch tracker exits, and are covered by deterministic seam tests.

## Implementation

- Added `DonatexWeb.Presence` to the supervision tree after `Donatex.PubSub` and before the endpoint.
- Added `DonatexWeb.Plugs.VisitorId` after `:fetch_session` in the browser pipeline to preserve or generate an opaque visitor ID.
- Updated `DonatexWeb.DonateLive` to subscribe, track, and then count authoritative Presence keys on connected mounts.
- Presence diffs trigger a fresh `Presence.list/1` count rather than join/leave arithmetic, preserving same-session multi-tab deduplication.
- Added isolated-topic lifecycle tests for count thresholds, real-time updates, multi-tab joins and leaves, accessibility, failure behavior, and disconnected rendering.
- Review follow-up: `:visitor_tracking_active` gates diffs; `:visitor_presence` Application env seam stubs track/list errors and exits in tests; lifecycle asserts use bounded eventual per-view sync (no `Process.sleep/1`).

## Verification

- Baseline `./init.sh`: 156 tests, 0 failures; Credo clean; Dialyzer 0 errors; duplication and architecture checks passed.
- Focused visitor and donor verification: `mix test test/donatex_web/plugs/visitor_id_test.exs test/donatex_web/live/donate_live_presence_test.exs test/donatex_web/live/donate_live_test.exs test/donatex_web/live/donate_live_feedback_cooldown_test.exs test/donatex_web/live/donate_live_tip_hardening_test.exs` — 34 tests, 0 failures.
- Final `mix ci`: 162 tests, 0 failures; format and warnings-as-errors compilation passed; Credo clean; Dialyzer 0 errors; duplication and architecture checks passed.
- Review follow-up (2026-07-19): `mix test` — 165 tests, 0 failures; `mix credo --strict` clean on changed files; compile warnings-as-errors passed.

## Remaining Deployment Validation

- Local single-node Presence behavior is verified.
- Before claiming one total across multiple production nodes, verify that the existing DNS cluster and PubSub configuration form a healthy cluster in the deployed environment. No deployment configuration change was part of this milestone.
