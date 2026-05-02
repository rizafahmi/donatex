# Project Progress

## Current State
- Latest commit: 224b973 (security(web): add CSP headers and production origin checks)
- Test status: 61 tests, 0 failures
- Lint: passing

## Completed
- [x] Donor form → Mayar dynamic QR → local `pending` donation row
- [x] Mayar webhook → DB transition to `paid` (deduped) → PubSub broadcast
- [x] Overlay consumes broadcasts, recovers missed alerts from DB, and plays alerts sequentially
- [x] Admin is basic-auth protected and can replay an alert without mutating `alerted`

## In Progress
- [ ] Donor page: live update from `pending` → `paid` without refresh, plus reconnect handling
- [ ] Donor page: “paid/success” UI state (distinct from waiting)
- [ ] Overlay: settle exact semantics of when `alerted` is marked (start vs completion) and test it
- [ ] Admin: polish list ordering, filter/readability, and add a clearer “replayed” confirmation flow
- [ ] Decide and test partial-failure behavior for “QR created but DB insert fails”

## Known Issues
- Mayar’s public webhook docs still do not publish a signature/HMAC verification scheme; MVP relies on an HTTPS callback URL with a non-guessable token until Mayar exposes an official signing mechanism
- The exact response shape of `POST /qrcode/create` still needs to be confirmed against real or sandbox responses
- The exact mapping between Mayar transaction identifiers and local donation rows still needs to be finalized during implementation
- Webhook parsing accepts `transactionId` with `id` as a fallback, and accepts `transactionStatus` with `status` as a fallback, until sandbox traffic confirms the final Mayar payload shape
- Pending donation cleanup behavior needs a final implementation decision if QR creation partially fails

## Next Steps
1. Donor page: live update from `pending` → `paid` without refresh, plus reconnect handling
2. Donor page: “paid/success” UI state (distinct from waiting)
3. Overlay: settle exact semantics of when `alerted` is marked (start vs completion) and test it
4. Admin: polish list ordering, filter/readability, and add a clearer “replayed” confirmation flow
5. Decide and test partial-failure behavior for “QR created but DB insert fails”

## References
- [DECISIONS.md](file:///Users/riza/code/donatex/docs/DECISIONS.md)
- [PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md)
- [ARCHITECTURE.md](file:///Users/riza/code/donatex/docs/ARCHITECTURE.md)
- [PRD.md](file:///Users/riza/code/donatex/docs/PRD.md)
- ADRs: [docs/decisions](file:///Users/riza/code/donatex/docs/decisions)
