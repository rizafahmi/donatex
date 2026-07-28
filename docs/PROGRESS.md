# Project Progress

## Current State
- Tip → Mayar QRIS path is rate-limited per peer IP via `SubmissionLimiter` (`{:tip, ip}`) before `create_qr` (fixes [#27](https://github.com/rizafahmi/donatex/issues/27)); persist-failure remains fail-closed for the donor; see [Milestone 14 log](milestones/14-tip-rate-limit/milestone-log.md)
- Webhook ops hardening for [#31](https://github.com/rizafahmi/donatex/issues/31) is complete; see [Milestone 13 log](milestones/13-webhook-ops-hardening/milestone-log.md)
- The `/qr` page now renders EQRCode's standards-compliant SVG in a white scannable card; PNG download serializes that SVG at 4× resolution while the existing info panel and expand/minimize cycle remain intact
- Toast/flash notifications now auto-dismiss after 5 s via a `FlashAutoHide` JS hook on the shared `flash/1` component (fixes [#39](https://github.com/rizafahmi/donatex/issues/39)); per-kind generations reset identical repeated flashes while connection-error toasts stay manual; see [Milestone 12 log](milestones/12-toast-auto-hide/milestone-log.md)
- Donor appreciation opt-in is now a prominent purple selectable CTA titled “Tambah tip untuk mendukung,” with the accurate “Mulai Rp5.000” entry price and a clear selected state; see [Milestone 4 log](file:///Users/riza/code/donatex/docs/milestones/4-optional-appreciation-experience/milestone-log.md)
- Milestone 10 (Audience Questions Board): complete — a secondary public Q&A surface at `/questions` lets the audience submit questions (optional name, else `Anonim`) and toggle one anonymous upvote per question; Today is ranked open→answered, votes desc, oldest first; prior WIB dates collapse and load on demand; an authenticated `/admin/questions` page lets the streamer answer/reopen/hide/restore; public and admin views converge in real time via PubSub; raw visitor ids are hashed (never persisted/logged); see [milestone-log](file:///Users/riza/code/donatex/docs/milestones/10-audience-questions-board/milestone-log.md) and [ADR-024](file:///Users/riza/code/donatex/docs/decisions/ADR-024-secondary-public-qa-questions-board.md)
- Milestone 9 (Donor Visitor Presence): complete — anonymous signed-session Presence counts unique browsers, deduplicates tabs, and shows real-time social proof only at 3+ visitors; review follow-up closed durable fail-hidden track/list failures and lifecycle test sync; see [milestone-log](file:///Users/riza/code/donatex/docs/milestones/9-donor-visitor-presence/milestone-log.md)
- Milestone 8 (SEO Optimization): complete — see [milestone-log](file:///Users/riza/code/donatex/docs/milestones/8-seo-optimization/milestone-log.md)
- Milestone 7 (End-to-End Refinement and Release Check): complete — see [milestone-log](file:///Users/riza/code/donatex/docs/milestones/7-end-to-end-refinement-release-check/milestone-log.md)
- Test status for the latest donor CTA change: 31 focused tests, 0 failures; format check and compile warnings-as-errors passed; mobile browser verification passed
- Donor submission now uses one mode-aware button: appreciation off sends free feedback; appreciation on continues through tip validation and QRIS
- Release status: mobile donor and OBS-sized browser smoke checks passed; ready for deployment configuration and a live Mayar transaction smoke check

## Completed
- [x] [#27](https://github.com/rizafahmi/donatex/issues/27) Tip path rate-limit Mayar QR + orphan QRIS fail-closed — see [Milestone 14 log](milestones/14-tip-rate-limit/milestone-log.md).
- [x] [#31](https://github.com/rizafahmi/donatex/issues/31) Webhook ops hardening — see [Milestone 13 log](milestones/13-webhook-ops-hardening/milestone-log.md).
- [x] Replace the decorative `/qr` lightning-dot grid with a scannable EQRCode SVG and SVG-based PNG download
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
- [x] Milestone 8 — SEO Optimization: robots.txt, canonical links, descriptive page titles, meta descriptions, sitemap.xml, llms.txt, Open Graph/Twitter Card tags, Strict-Transport-Security trust signal header, Organization & FAQPage JSON-LD schemas, and 301 permanent redirect for /donate.
- [x] Visitor Analytics & Conversion Funnel: Track raw page views on `/` dynamically via connected socket, broadcast page views via PubSub, and render real-time conversion rates (Feedback & Tip Conversion) on `/admin` with a premium glassmorphic visual card.
- [x] Milestone 9 — Donor Visitor Presence: Track ephemeral signed browser sessions with Phoenix Presence, deduplicate multiple tabs, and show an exact real-time count only at three or more visitors.
- [x] Milestone 10 — Audience Questions Board: secondary public `/questions` Q&A surface with anonymous upvotes, WIB-grouped ranked board, and authenticated `/admin/questions` moderation (answer/reopen/hide/restore); generalized `SubmissionLimiter`; raw visitor ids hashed and never persisted/logged.
- [x] [#39](https://github.com/rizafahmi/donatex/issues/39) Toast auto-hide — see [Milestone 12 log](milestones/12-toast-auto-hide/milestone-log.md).

## In Progress
- [#25](https://github.com/rizafahmi/donatex/issues/25) Make paid webhook transitions concurrency-safe — PR [#34](https://github.com/rizafahmi/donatex/pull/34): atomic pending→paid claim; cursor-agent loop CLEAN.
- [#24](https://github.com/rizafahmi/donatex/issues/24) Questions WIB/today empty listing — fixed on the same PR by making questions tests calendar-relative to `today_wib()` (hardcoded `2026-07-25` drifted).

## Known Issues
- Mayar’s public webhook docs still do not publish a signature/HMAC verification scheme; MVP relies on an HTTPS callback URL with a non-guessable token until Mayar exposes an official signing mechanism
- Webhook parsing accepts `transactionId` with `id` as a fallback, and accepts `transactionStatus` with `status` as a fallback, until sandbox traffic confirms the final Mayar payload shape
- If Mayar omits `transactionId`/`id` and `/transactions/unpaid` does not return a single fresh same-amount match, Donatex now fails closed and does not show the QR rather than risk an uncorrelatable payment
- Cross-node visitor totals depend on healthy production DNS clustering and PubSub; only single-node Presence behavior has been verified locally

## Next Steps
1. Merge open hardening PRs still awaiting review (#26 amount-fallback, #28 overlay persist, #31 webhook ops) as they land.
2. Next high-impact bugs without PRs: admin LiveView re-auth (#30), questions vote race (#29), flaky admin/donor suite (#32).
3. Configure the production environment and deploy using the documented release process.
4. Verify production DNS cluster membership and that donor Presence totals propagate across nodes before making cross-node count claims.
5. Run one final low-value live Mayar QRIS transaction against the deployed callback URL.

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
- Milestone 8 log: [docs/milestones/8-seo-optimization/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/8-seo-optimization/milestone-log.md)
- Milestone 9 log: [docs/milestones/9-donor-visitor-presence/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/9-donor-visitor-presence/milestone-log.md)
- Milestone 10 log: [docs/milestones/10-audience-questions-board/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/10-audience-questions-board/milestone-log.md)
- Milestone 14 log: [docs/milestones/14-tip-rate-limit/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/14-tip-rate-limit/milestone-log.md)
- Milestone 13 log: [docs/milestones/13-webhook-ops-hardening/milestone-log.md](file:///Users/riza/code/donatex/docs/milestones/13-webhook-ops-hardening/milestone-log.md)
- ADRs: [docs/decisions](file:///Users/riza/code/donatex/docs/decisions)
