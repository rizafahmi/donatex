# Project Progress

## Current State
- Latest commit: f163748 (feat(overlay): add synced canvas confetti burst for maximum celebration)
- Working tree: has uncommitted changes for the donor/overlay engagement refresh, plus an existing `.gitignore` change
- Test status: 74 tests, 0 failures
- Lint: `mix credo` passing
- Dialyzer: `mix dialyzer` passing
- Full verification: `mix precommit` passing

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

## In Progress


## Known Issues
- Mayar’s public webhook docs still do not publish a signature/HMAC verification scheme; MVP relies on an HTTPS callback URL with a non-guessable token until Mayar exposes an official signing mechanism
- Webhook parsing accepts `transactionId` with `id` as a fallback, and accepts `transactionStatus` with `status` as a fallback, until sandbox traffic confirms the final Mayar payload shape
- If Mayar omits `transactionId`/`id` and `/transactions/unpaid` does not return a single fresh same-amount match, Donatex now fails closed and does not show the QR rather than risk an uncorrelatable payment

## Next Steps
1. Deploy the build containing the removed QR-URL transaction-id fallback.
2. On the next live payment, compare `Mayar create_qr ok ... id_source=... mayar_transaction_id=...`, `Pending donation created ... mayar_transaction_id=...`, and webhook logs to confirm the same transaction id flows end to end.

## References
- [DECISIONS.md](file:///Users/riza/code/donatex/docs/DECISIONS.md)
- [PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md)
- [ARCHITECTURE.md](file:///Users/riza/code/donatex/docs/ARCHITECTURE.md)
- [PRD.md](file:///Users/riza/code/donatex/docs/PRD.md)
- ADRs: [docs/decisions](file:///Users/riza/code/donatex/docs/decisions)
