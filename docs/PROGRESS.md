# Progress

## Current Status

MVP build is in progress and already has an end-to-end “happy path” skeleton:

- Donor form → Mayar dynamic QR → local `pending` donation row
- Mayar webhook → DB state transition to `paid` (deduped) → PubSub broadcast
- Overlay consumes broadcasts, recovers missed alerts from DB, and plays alerts sequentially
- Admin is basic-auth protected and can replay an alert without mutating `alerted`

The canonical plan is [PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md); this file is intentionally a short status summary.

## Current Architecture Direction

- Phoenix LiveView monolith
- SQLite as the source of truth
- `Req` for Mayar integration
- Phoenix PubSub for internal real-time event delivery
- Overlay queue lives in `OverlayLive` state, not a dedicated GenServer or external broker
- Donation lifecycle is `pending -> paid`, with `alerted` tracked separately for overlay recovery

Reference docs:

- [PRD.md](file:///Users/riza/code/donatex/docs/PRD.md)
- [PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md)
- [ARCHITECTURE.md](file:///Users/riza/code/donatex/docs/ARCHITECTURE.md)
- ADRs: [docs/decisions](file:///Users/riza/code/donatex/docs/decisions)

## Open Risks And Unknowns

- Mayar’s public webhook docs still do not publish a signature or HMAC verification scheme; MVP will rely on an HTTPS callback URL with a non-guessable token until Mayar exposes an official signing mechanism
- The exact response shape of `POST /qrcode/create` still needs to be confirmed against real or sandbox responses
- The exact mapping between Mayar transaction identifiers and local donation rows still needs to be finalized during implementation
- Webhook parsing currently accepts `transactionId` with `id` as a fallback, and accepts `transactionStatus` with `status` as a fallback, until sandbox traffic confirms the final Mayar payload shape
- Pending donation cleanup behavior needs a final implementation decision if QR creation partially fails

## Next Work

- Donor page: live update from `pending` → `paid` without refresh, plus reconnect handling
- Donor page: “paid/success” UI state (distinct from waiting)
- Overlay: settle exact semantics of when `alerted` is marked (start vs completion) and test it
- Admin: polish list ordering, filter/readability, and add a clearer “replayed” confirmation flow
- Decide and test partial-failure behavior for “QR created but DB insert fails”

## Recently Verified

- `mix test`
- `mix credo --strict`

## Notes

- As features become covered by tests, we prefer to move detail into tests and keep this file short.
