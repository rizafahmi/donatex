# Project Progress

## Current State
- Latest commit: 142d725 (docs(adr): record webhook acceptance criteria)
- Working tree: has uncommitted changes
- Test status: 69 tests, 0 failures
- Lint: `mix credo` passing
- Dialyzer: `mix dialyzer` passing

## Completed
- [x] Donor form → Mayar dynamic QR → local `pending` donation row
- [x] Mayar webhook → DB transition to `paid` (deduped) → PubSub broadcast
- [x] Overlay consumes broadcasts, recovers missed alerts from DB, and plays alerts sequentially
- [x] Admin is basic-auth protected and can replay an alert without mutating `alerted`
- [x] Mayar client requires a transaction id, validates QR image URL schemes, and avoids logging usable QR URLs
- [x] Decide and test partial-failure behavior for “QR created but DB insert fails”
- [x] Add safe lifecycle logging (QR creation, webhook accept/reject/duplicate, admin replay)

## In Progress
- [ ] Confirm Mayar `POST /qrcode/create` response shape against real/sandbox traffic (field names, expiry semantics)
- [ ] Document setup and deployment details (env vars, webhook registration, private URLs)
- [ ] Run a final end-to-end verification pass (`mix precommit` + manual smoke test)

## Known Issues
- Mayar’s public webhook docs still do not publish a signature/HMAC verification scheme; MVP relies on an HTTPS callback URL with a non-guessable token until Mayar exposes an official signing mechanism
- The exact response shape of `POST /qrcode/create` still needs to be confirmed against real or sandbox responses
- Webhook parsing accepts `transactionId` with `id` as a fallback, and accepts `transactionStatus` with `status` as a fallback, until sandbox traffic confirms the final Mayar payload shape

## Next Steps
1. Confirm Mayar `POST /qrcode/create` response shape against real/sandbox traffic (field names, expiry semantics)
2. Document setup and deployment details (env vars, webhook registration, private URLs)
3. Run a final end-to-end verification pass (`mix precommit` + manual smoke test)

## References
- [DECISIONS.md](file:///Users/riza/code/donatex/docs/DECISIONS.md)
- [PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md)
- [ARCHITECTURE.md](file:///Users/riza/code/donatex/docs/ARCHITECTURE.md)
- [PRD.md](file:///Users/riza/code/donatex/docs/PRD.md)
- ADRs: [docs/decisions](file:///Users/riza/code/donatex/docs/decisions)
