# Progress

## Current Status

Donatex is in Phase 2 implementation. Foundation Tasks 1-4 are complete (Phoenix app + SQLite + runtime config + placeholder routes). Data Model Task 5 (donations migration) and Task 6 (Donation schema + changeset) are complete. Next is the Donations context + persistence behavior tests (Tasks 7-8).

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

## Open Risks And Unknowns

- Mayar’s public webhook docs do not clearly document a signature or HMAC verification scheme
- The exact response shape of `POST /qrcode/create` still needs to be confirmed against real or sandbox responses
- The exact mapping between Mayar transaction identifiers and local donation rows still needs to be finalized during implementation
- Pending donation cleanup behavior needs a final implementation decision if QR creation partially fails

## Not Started Yet

- Donations context
- Mayar API client
- Webhook controller and webhook processing pipeline
- Donor LiveView
- Overlay LiveView
- Admin LiveView
- Basic auth plug for admin
- End-to-end donation lifecycle implementation

## Recommended Next Step

Implement Task 7 from [docs/PLAN.md](file:///Users/riza/code/donatex/docs/PLAN.md): add the Donations context functions used by QR generation, webhook ingestion, overlay recovery, and admin listing.
