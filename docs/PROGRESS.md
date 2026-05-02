# Project Progress

## Current State
- Latest commit: 142d725 (docs(adr): record webhook acceptance criteria)
- Working tree: has uncommitted changes
- Test status: 72 tests, 0 failures
- Lint: `mix credo` passing
- Dialyzer: `mix dialyzer` passing
- Full verification: `mix precommit` passing

## Completed
- [x] Donor form → Mayar dynamic QR → local `pending` donation row
- [x] Mayar webhook → DB transition to `paid` (deduped) → PubSub broadcast
- [x] Overlay consumes broadcasts, recovers missed alerts from DB, and plays alerts sequentially
- [x] Admin is basic-auth protected and can replay an alert without mutating `alerted`
- [x] Mayar client extracts a stable transaction id (response `transactionId`/`id` or UUID in the QR URL), validates QR image URL schemes, and avoids logging usable QR URLs
- [x] Decide and test partial-failure behavior for “QR created but DB insert fails”
- [x] Add safe lifecycle logging (QR creation, webhook accept/reject/duplicate, admin replay)
- [x] Confirm Mayar `POST /qrcode/create` response shape against real traffic (can return only `data.amount` + `data.url`)
- [x] Add `x-content-type-options: nosniff` to shared browser security headers

## In Progress
- [ ] Confirm webhook transaction id matches the QR create identifier (response `transactionId`/`id` or UUID extracted from QR URL)
- [ ] Document setup and deployment details (env vars, webhook registration, private URLs)
- [ ] Run a final end-to-end verification pass (manual smoke test)

## Known Issues
- Mayar’s public webhook docs still do not publish a signature/HMAC verification scheme; MVP relies on an HTTPS callback URL with a non-guessable token until Mayar exposes an official signing mechanism
- Webhook parsing accepts `transactionId` with `id` as a fallback, and accepts `transactionStatus` with `status` as a fallback, until sandbox traffic confirms the final Mayar payload shape

## Next Steps
1. Confirm webhook transaction id matches the QR create identifier (response `transactionId`/`id` or UUID extracted from QR URL)
2. Document setup and deployment details (env vars, webhook registration, private URLs)
3. Run a final end-to-end verification pass (manual smoke test)

## References
- [DECISIONS.md](file:///Users/riza/code/donatex/docs/DECISIONS.md)
- [PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md)
- [ARCHITECTURE.md](file:///Users/riza/code/donatex/docs/ARCHITECTURE.md)
- [PRD.md](file:///Users/riza/code/donatex/docs/PRD.md)
- ADRs: [docs/decisions](file:///Users/riza/code/donatex/docs/decisions)
