# Project Progress

## Current State
- Milestone 7 (End-to-End Refinement and Release Check): complete — see [milestone-log](file:///Users/riza/code/donatex/docs/milestones/7-end-to-end-refinement-release-check/milestone-log.md)
- Test status: 144 tests, 0 failures; Credo clean; Dialyzer 0 errors; duplication and architecture checks passed
- Donor submission now uses one mode-aware button: appreciation off sends free feedback; appreciation on continues through tip validation and QRIS
- Release status: mobile donor and OBS-sized browser smoke checks passed; ready for deployment configuration and a live Mayar transaction smoke check

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
- [x] M4 appreciation warnings fix (W1–W8): Pending live-insert filter, sticky tip guard + tests, free step guard, tip preserve merge, atomic feedback rate limiter
- [x] Milestone 5 — Unified Admin Inbox: All/Tips/Feedback filters; card fields (reaction, type, time, status); tip-only replay guard; live free + paid updates; Notes empty state
- [x] Milestone 6 — Notable branding / public route polish (per PRD) & redirect /donate to /
- [x] Refresh admin header/subtitle remaining "donation" wording to "notes and tips"
- [x] Complete corrective Milestone 6 user-visible copy audit across donor validation/errors, admin missing-record messages, shared navigation, and overlay terminal branding
- [x] Milestone 7 — Remove manual-paid bypass so only Mayar confirmation can promote pending tips
- [x] Align free reaction timing to 3–4 seconds and donor message input to the 280-character server limit
- [x] Add Indonesian document metadata, live status announcements, and reduced-motion fallbacks
- [x] Verify mobile free feedback, OBS transparency/layout, restart recovery, auto-dismiss persistence, and paid-tip replay in a real browser
- [x] Run the final 144-test, Credo, Dialyzer, duplication, and architecture quality gate
- [x] Unify free feedback and tip submission behind one mode-aware donor-form button and one `submit_feedback` event

## In Progress


## Known Issues
- Mayar’s public webhook docs still do not publish a signature/HMAC verification scheme; MVP relies on an HTTPS callback URL with a non-guessable token until Mayar exposes an official signing mechanism
- Webhook parsing accepts `transactionId` with `id` as a fallback, and accepts `transactionStatus` with `status` as a fallback, until sandbox traffic confirms the final Mayar payload shape
- If Mayar omits `transactionId`/`id` and `/transactions/unpaid` does not return a single fresh same-amount match, Donatex now fails closed and does not show the QR rather than risk an uncorrelatable payment

## Next Steps
1. Configure the production environment and deploy using the documented release process.
2. Run one final low-value live Mayar QRIS transaction against the deployed callback URL.

## References
- [DECISIONS.md](file:///Users/riza/code/donatex/docs/DECISIONS.md)
- [PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md)
- [ARCHITECTURE.md](file:///Users/riza/code/donatex/docs/ARCHITECTURE.md)
- [PRD.md](file:///Users/riza/code/donatex/docs/PRD.md)
- Milestone 2 log: [docs/milestones/2-free-notes-safe-submission/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/2-free-notes-safe-submission/milestone-log.md)
- Milestone 3 log: [docs/milestones/3-floating-overlay-reactions/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/3-floating-overlay-reactions/milestone-log.md)
- Milestone 4 log: [docs/milestones/4-optional-appreciation-experience/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/4-optional-appreciation-experience/milestone-log.md)
- Milestone 5 log: [docs/milestones/5-unified-admin-inbox/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/5-unified-admin-inbox/milestone-log.md)
- Milestone 6 log: [docs/milestones/6-notable-branding-routing/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/6-notable-branding-routing/milestone-log.md)
- Milestone 7 log: [docs/milestones/7-end-to-end-refinement-release-check/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/7-end-to-end-refinement-release-check/milestone-log.md)
- ADRs: [docs/decisions](file:///Users/riza/code/donatex/docs/decisions)
