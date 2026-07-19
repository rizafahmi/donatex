# Milestone 7 — End-to-End Refinement and Release Check

## What's new in the app
- Pending tips can only become paid through Mayar confirmation; the admin no longer offers a manual payment shortcut.
- Free overlay reactions now complete within the approved 3–4 second window.
- Viewers can enter the full 280-character message limit supported by server validation.
- Indonesian document metadata and polite status announcements make payment and thank-you transitions clearer to assistive technology.
- Reduced-motion users receive static, readable feedback and tip alerts instead of animated movement and pulsing effects.

## What was built

### Confirmed-only tip lifecycle
- Removed the pending-tip `Mark Paid` action and event from `DonatexWeb.AdminLive`.
- Removed the now-unused `Donatex.Donations.mark_paid_by_id/1` API.
- Kept paid-tip replay unchanged: replay broadcasts an already-confirmed tip without changing its persisted `alerted` state.
- Added regression coverage proving pending admin cards do not expose manual payment confirmation.

### Donor and accessibility refinement
- Aligned the donor textarea `maxlength` with the existing 280-character changeset validation.
- Set the root document language to Indonesian (`lang="id"`).
- Added polite live status regions to the pending-payment indicator, free-feedback thank-you state, and confirmed-tip thank-you state.
- Extended donor LiveView and QR journey tests to cover these browser contracts.

### Overlay refinement
- Changed free-reaction float duration from 6–8 seconds to the PRD-required 3–4 seconds and aligned the CSS fallback to 3.5 seconds.
- Added `prefers-reduced-motion` fallbacks for custom neon effects, floating reactions, and terminal tip celebrations. Alerts remain visible and readable without movement.
- Added regression coverage for the float duration range and reduced-motion stylesheet rules.

### Routes, models, and storage
- No routes, schemas, migrations, or persisted fields were added.
- Existing public surfaces remain `/`, `/overlay`, and basic-auth-protected `/admin`; `/donate` continues to redirect to `/`.
- Browser smoke checks created development-only feedback and paid-tip records to exercise mobile submission, restart recovery, auto-dismiss persistence, and replay. No test or production database fixtures were added.

## Unspecified implementation decisions
- Removed manual payment confirmation rather than hiding only its button, so a crafted LiveView event cannot bypass Mayar confirmation.
- Attached live-region semantics to concise state containers, especially the payment-waiting badge, to avoid unnecessarily verbose screen-reader announcements.
- Reduced-motion mode keeps overlay content statically visible for the existing lifecycle duration instead of suppressing alerts.
- Retained the existing expected local-browser autoplay warning. Chrome blocks unprompted audio during local checks; OBS Browser Sources permit it.

## What a future maintainer needs to know
- Mayar confirmation remains the only transition from pending to paid. Do not reintroduce an admin/manual-paid path without changing the approved product scope.
- Free reactions use one generated duration for both the LiveView dismissal timer and CSS animation through `--float-duration`.
- The reduced-motion rules live at the end of `assets/css/app.css`; keep static `opacity` and `transform` fallbacks when changing overlay animations.
- Webhook coverage continues to verify confirmed-only handling, amount mismatch rejection, deduplication, persisted paid state, and one broadcast. `Repo.update/1` completes before `PubSub.broadcast/3` in the controller path.

## PRD deviations
- No implementation scope deviations.
- The final local browser pass did not create a charge against the live Mayar API. The complete QR creation and webhook-confirmation journey was verified with the existing Req-backed PhoenixTest flow; previous milestones retain the real-response-shape findings.

## Verification
- `./init.sh` passed on 2026-07-18:
  - 144 ExUnit/PhoenixTest tests, 0 failures
  - Credo: no issues
  - Dialyzer: 0 errors
  - duplication check: passed
  - architecture policy: passed
- Browser smoke check with Chrome automation:
  - iPhone 14 viewport (390×844): donor page readable with no horizontal overflow; `lang="id"`; textarea limit 280; free feedback submitted and announced through the polite status region.
  - OBS viewport (1920×1080): transparent HTML/body backgrounds, exact viewport-sized overlay, no horizontal overflow, and readable donor/amount/message content.
  - Reduced-motion emulation: terminal alert and text rendered statically with `animation-name: none`, visible opacity, and stable transforms.
  - Restart recovery: an unalerted paid tip was recovered after restarting the Phoenix server, displayed, dismissed, and persisted as `alerted: true`.
  - Admin replay: the recovered paid tip was replayed into a connected overlay; no `Mark Paid` action was present.
  - Browser console: no runtime errors; only the documented local autoplay warning.
- Automated coverage verifies concurrent free-reaction floats, sequential paid celebrations, no free-reaction recovery, confirmed-only webhook behavior, mismatch rejection, deduplication, and paid-tip-only replay.

## Done-when result
- Milestone 7 is complete. The free and tipped paths, unified overlay, restart recovery, replay, webhook safety, accessibility refinements, and full quality gate satisfy the approved release-check criteria.

## Post-milestone donor submit refinement — 2026-07-19

- Replaced the separate free-feedback and tip CTAs with one submit button whose label and supporting text reflect the appreciation toggle.
- Unified button clicks and Enter-key submission through `submit_feedback`; submitted `donation_form[show_appreciation]` selects the free or tip path.
- Removed the top-level `_tip` routing contract while preserving separate free/tip validation, amount recovery, QRIS creation, cooldown, and duplicate-tip guards.
- Updated LiveView, hardening, cooldown, and PhoenixTest QR journey coverage.
- Focused donor suites: 35 tests, 0 failures.
- `mix ci`: 144 tests, 0 failures; Credo clean; Dialyzer 0 errors; duplication and architecture checks passed.
