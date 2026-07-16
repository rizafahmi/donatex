# Project Progress

## Current State
- Milestone 4 (Optional Appreciation Experience): complete — see [milestone-log](file:///Users/riza/code/donatex/docs/milestones/4-optional-appreciation-experience/milestone-log.md)
- M4 tip-path hardening (W1–W6): complete — appreciation is a form checkbox; amounts preserved while collapsed; tip submits live form values; double-submit guarded
- M4 review follow-up (S1–S5): complete — Enter→free documented/locked; tip gated on appreciation params; paid CTA “Kirim lagi”; hero copy helper; back-reset refutes tip CTA
- Test status: 113 tests, 0 failures

## Completed
- [x] Donor form → Mayar dynamic QR → local `pending` donation row
- [x] Mayar webhook → DB transition to `paid` (deduped) → PubSub broadcast
- [x] Overlay consumes broadcasts, recovers missed alerts from DB, and plays alerts sequentially
- [x] Admin is basic-auth protected and can replay an alert without mutating `alerted`
- [x] Mayar client resolves a stable transaction id from the QR create response (`transactionId`/`id`) or a unique recent `/transactions/unpaid` lookup, validates QR image URL schemes, and avoids logging usable QR URLs
- [x] Mayar create QR logging indicates whether the transaction id came from response fields or unpaid-transaction lookup (`id_source=response|unpaid`) and whether the QR asset UUID matched the stored transaction id
- [x] Decide and test partial-failure behavior for “QR created but DB insert fails”
- [x] Add safe lifecycle logging (QR creation, webhook accept/reject/duplicate, admin replay)
- [x] Confirm Mayar `POST /qrcode/create` response shape against real traffic (can return only `data.amount` + `data.url`)
- [x] Add `x-content-type-options: nosniff` to shared browser security headers
- [x] Fix donor custom amount browser validation by aligning input `min`/`step` and enforcing server-side multiples-of-1000
- [x] Add feature coverage for webhook correlation when QR create omits transaction id and the real transaction id is resolved from `/transactions/unpaid`
- [x] Fix Credo nesting findings in DonateLive amount validation and Mayar create QR logging helpers
- [x] Stabilize SQLite DB tests by running donations DataCase tests non-async
- [x] Validate donation query indexes (`donations_recovery_queue_idx`, `donations_order_idx`) via migration tests
- [x] Fix live Mayar correlation failure where the QR image UUID differed from the webhook `transactionId` by resolving the real transaction id from `/transactions/unpaid` and failing closed when it cannot be uniquely determined
- [x] Remove the stale QR asset UUID fallback in code so omitted `transactionId`/`id` responses always resolve correlation via `/transactions/unpaid` instead of trusting the QR filename
- [x] Apply custom HTML/CSS alert design from user requirements
- [x] Blend custom overlay design with Donatex aesthetic (glassmorphism, accent colors, typography)
- [x] Add high-performance canvas confetti burst synced with the audio to maximize celebratory feel
- [x] Add sound effect playback (`smb_stage_clear.wav`) when overlay alerts appear
- [x] Tune overlay alert timing (~8.5 seconds end-to-end) so the audio cue and exit animation can finish cleanly
- [x] Refresh `/` donor page copy/layout and `/overlay` idle prompt to make donation more inviting
- [x] Polish `/overlay` visual styling, typography, layout, and transitions (smooth 60fps compositor animation, glow borders, flexbox alignment, and zero gradient text)
- [x] Document setup and deployment details (env vars, webhook registration, private webhook URL)
- [x] Run a final end-to-end verification pass (manual smoke test)
- [x] Polish `/admin` dashboard layout, typography, telemetry stats, and real-time PubSub updates (new pending, paid status changes, alerted updates, empty state, donor message display, and semantic color matching)
- [x] Add status filters (all, paid, pending) to `/admin` dashboard with paid as default
- [x] Align the overall color scheme and vibe with the user's livestream overlay (cyan and purple developer-terminal aesthetic, terminal window alert layout on `/overlay`)
- [x] Milestone 2 — Free Notes with Safe Submission: free submit + thank-you, 10s peer-IP cooldown, tip secondary path, admin default `all`, nil-amount display, live insert, no replay for sent
- [x] Milestone 3 — Floating Overlay Reactions: free Notes float emoji-only on `/overlay` (3–4s, simultaneous, no recovery); tip celebrations unchanged
- [x] Milestone 4 — Optional Appreciation Experience: collapsed appreciation toggle; free feedback default; tip QR with back/reset and retryable errors
- [x] M4 tip-path hardening: `<.input>` appreciation checkbox, amount preserve on validate, tip submitter `_tip`, `:tip_submitting` guard, toggle-off + free-with-appreciation tests
- [x] M4 review follow-up (S1–S5): Enter→free product lock, tip appreciation gate, paid-step copy, back-reset tip refute, `donor_hero_headline/0`

## In Progress


## Known Issues
- Mayar’s public webhook docs still do not publish a signature/HMAC verification scheme; MVP relies on an HTTPS callback URL with a non-guessable token until Mayar exposes an official signing mechanism
- Webhook parsing accepts `transactionId` with `id` as a fallback, and accepts `transactionStatus` with `status` as a fallback, until sandbox traffic confirms the final Mayar payload shape
- If Mayar omits `transactionId`/`id` and `/transactions/unpaid` does not return a single fresh same-amount match, Donatex now fails closed and does not show the QR rather than risk an uncorrelatable payment

## Next Steps
1. Milestone 5 — Unified Admin Inbox (Tips/Feedback filters; tip-only replay; live free + paid updates)
2. Keep donor appreciation toggle and overlay float/tip paths intact while reshaping admin filters

## References
- [DECISIONS.md](file:///Users/riza/code/donatex/docs/DECISIONS.md)
- [PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md)
- [ARCHITECTURE.md](file:///Users/riza/code/donatex/docs/ARCHITECTURE.md)
- [PRD.md](file:///Users/riza/code/donatex/docs/PRD.md)
- Milestone 2 log: [docs/milestones/2-free-notes-safe-submission/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/2-free-notes-safe-submission/milestone-log.md)
- Milestone 3 log: [docs/milestones/3-floating-overlay-reactions/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/3-floating-overlay-reactions/milestone-log.md)
- ADRs: [docs/decisions](file:///Users/riza/code/donatex/docs/decisions)
