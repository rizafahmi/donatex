# Progress

## Current Status

Donatex is in Phase 4 implementation. Foundation Tasks 1-4 are complete, Data Model Tasks 5-8 are complete, and Mayar Integration Tasks 9-13 are complete. Next is Task 14: build the donor form UI.

## Completed

- Confirmed core product direction from [docs/PRD.md](file:///Users/riza/code/donatex/docs/PRD.md)
- Identified and documented the hard constraints for the MVP
- Created the implementation plan in [docs/PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md)
- Created the target architecture document in [docs/ARCHITECTURE.md](file:///Users/riza/code/donatex/docs/ARCHITECTURE.md)
- Added initial architecture decision records in [docs/decisions](file:///Users/riza/code/donatex/docs/decisions)
- Confirmed the project should be a brand-new Phoenix app for a single-streamer deployment
- Locked these product decisions:
  - create local donation rows at QR generation time
  - donor page should live-update after payment confirmation
  - admin replay should rebroadcast without resetting `alerted`
  - deployment target is single streamer and single overlay
  - secrets should be env-driven via `.env` in local development
- Fixed the Dialyzer/`mix precommit` issue by adding `:ex_unit` to the Dialyzer PLT config in [mix.exs](file:///Users/riza/code/donatex/mix.exs)
- Verified `mix dialyzer`, `mix test`, and `mix precommit` pass on the current codebase
- Completed Foundation Task 1 (Phoenix app bootstrap)
- Completed Foundation Task 2 (SQLite repo wiring)
- Implemented env-driven runtime configuration and `.env` workflow (Task 3), including a centralized config access module and tests
- Hardened secrets hygiene by ignoring `.env` and common key/cert files in `.gitignore`
- Completed Foundation Task 4 (route placeholders for donor, overlay, admin, and Mayar webhook)
- Completed Data Model Task 5 (donations migration + unique index + verification test)
- Completed Data Model Task 6 (Donation schema + changeset validations + schema tests)
- Completed Data Model Task 7 (Donations context with create/mark-paid/recovery-query/mark-alerted/admin-list APIs and tests)
- Completed Data Model Task 8 (persistence behavior tests for dedupe + state transitions + recovery query)
- Completed Mayar Integration Task 9 (validated that Mayar docs do not publish webhook signing details and chose the MVP fallback trust model)
- Extended the env/config contract with `MAYAR_WEBHOOK_TOKEN` so webhook auth can be enforced without revisiting runtime configuration
- Documented the Mayar webhook fallback strategy in the README and an ADR
- Completed Mayar Integration Task 10 (defined the internal Mayar client contract and normalized return type)
- Completed Mayar Integration Task 11 (implemented the `Req`-backed Mayar API client with normalized success and error handling)
- Completed Mayar Integration Task 12 (covered the Mayar client with mocked success, API error, and network failure tests)
- Completed Mayar Integration Task 13 (extracted webhook payload parsing into `Donatex.Mayar.Webhook` and covered `payment.received` parsing, safe ignore behavior, and missing-field rejection)

## Current Architecture Direction

- Phoenix LiveView monolith
- SQLite as the source of truth
- `Req` for Mayar integration
- Phoenix PubSub for internal real-time event delivery
- Overlay queue lives in `OverlayLive` state, not a dedicated GenServer or external broker
- Donation lifecycle is `pending -> paid`, with `alerted` tracked separately for overlay recovery

## Documentation Created

- [docs/PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md)
- [docs/ARCHITECTURE.md](file:///Users/riza/code/donatex/docs/ARCHITECTURE.md)
- [docs/decisions/ADR-001-phoenix-liveview-monolith.md](file:///Users/riza/code/donatex/docs/decisions/ADR-001-phoenix-liveview-monolith.md)
- [docs/decisions/ADR-002-persist-pending-donations.md](file:///Users/riza/code/donatex/docs/decisions/ADR-002-persist-pending-donations.md)
- [docs/decisions/ADR-003-overlay-queue-in-liveview.md](file:///Users/riza/code/donatex/docs/decisions/ADR-003-overlay-queue-in-liveview.md)
- [docs/decisions/ADR-004-env-driven-runtime-config.md](file:///Users/riza/code/donatex/docs/decisions/ADR-004-env-driven-runtime-config.md)
- [docs/decisions/ADR-005-placeholder-public-surfaces.md](file:///Users/riza/code/donatex/docs/decisions/ADR-005-placeholder-public-surfaces.md)
- [docs/decisions/ADR-006-donations-table-schema.md](file:///Users/riza/code/donatex/docs/decisions/ADR-006-donations-table-schema.md)
- [docs/decisions/ADR-008-mayar-webhook-authenticity-fallback.md](file:///Users/riza/code/donatex/docs/decisions/ADR-008-mayar-webhook-authenticity-fallback.md)

## Open Risks And Unknowns

- Mayar’s public webhook docs still do not publish a signature or HMAC verification scheme; MVP will rely on an HTTPS callback URL with a non-guessable token until Mayar exposes an official signing mechanism
- The exact response shape of `POST /qrcode/create` still needs to be confirmed against real or sandbox responses
- The exact mapping between Mayar transaction identifiers and local donation rows still needs to be finalized during implementation
- Webhook parsing currently accepts `transactionId` with `id` as a fallback, and accepts `transactionStatus` with `status` as a fallback, until sandbox traffic confirms the final Mayar payload shape
- Pending donation cleanup behavior needs a final implementation decision if QR creation partially fails

## Not Started Yet

- Mayar API client
- Webhook controller and webhook processing pipeline
- Donor LiveView
- Overlay LiveView
- Admin LiveView
- Basic auth plug for admin
- End-to-end donation lifecycle implementation

## Recently Verified

- `mix test test/donatex/mayar/client_test.exs`
- `mix test test/donatex/mayar/webhook_test.exs test/donatex_web/controllers/mayar_webhook_controller_test.exs`
- `mix test`

## Recommended Next Step

Implement Task 14 from [docs/PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md): build the donor form UI.
