# Implementation Plan: Livestream Donation System

## Overview

Build a single-streamer Phoenix LiveView app that lets viewers create a QRIS donation from a public donor page, then shows confirmed donations as sequential alerts in an OBS overlay. Donations are stored in SQLite, created locally at QR generation time as `pending`, updated to `paid` when Mayar sends a webhook, and replayable from a basic-auth admin page.

## Locked Decisions

- This repo will contain a brand-new Phoenix app.
- A donation row is created locally when the QR is generated, not only when payment is confirmed.
- The donor page should live-update to a paid/success state after webhook confirmation.
- Admin replay should rebroadcast an alert without mutating the donation back to `alerted: false`.
- Deployment is single-streamer and single-overlay only.
- Secrets and credentials should live in `.env` and be loaded with `source .env` during development.

## Mayar Source Notes

- Mayar Headless API uses Bearer auth with an API key, production base URL `https://api.mayar.id/hl/v1`, sandbox base URL `https://api.mayar.club/hl/v1`, and a documented rate limit of 20 requests per minute.
- The public Postman collection documents `POST /qrcode/create` with a JSON body containing `amount`.
- The webhook section documents webhook registration, testing, retry, and history endpoints, and documents `payment.received` payload fields including `event`, `data.id`, `data.transactionId`, `data.transactionStatus`, `data.customerName`, and `data.amount`.
- The webhook docs do not document any signature header, HMAC scheme, or shared-secret verification method. Treat that as an integration risk to validate early.

## Architecture Decisions

- Use Phoenix LiveView for donor page, overlay, and admin page to keep the app single-stack and real-time.
- Use SQLite through Ecto for local durability and restart recovery.
- Persist donations before broadcasting alerts. Overlay recovery should query `status = paid AND alerted = false`.
- Keep alert queue logic inside the overlay LiveView for MVP. Do not introduce a separate queue process unless the single-process approach proves insufficient.
- Use Phoenix PubSub for webhook-to-overlay and admin-replay-to-overlay event delivery.
- Because Mayar webhook authenticity is not documented, plan for a dedicated verification spike before finalizing the webhook security model.

## Dependency Graph

```diagram
╭──────────────────────╮
│ Phoenix app/config   │
╰──────────┬───────────╯
           ▼
╭──────────────────────╮
│ donations migration  │
╰──────────┬───────────╯
           ▼
╭──────────────────────╮
│ Donation schema +    │
│ context              │
╰──────┬────────┬──────╯
       │        │
       ▼        ▼
╭────────────╮  ╭─────────────────╮
│ Mayar API  │  │ Webhook parsing │
│ client     │  │ + authenticity  │
╰─────┬──────╯  ╰────────┬────────╯
      │                  ▼
      ▼          ╭─────────────────╮
╭──────────────╮ │ DB write +       │
│ Donor flow   │ │ PubSub broadcast │
╰──────────────╯ ╰────────┬────────╯
                          ▼
                   ╭───────────────╮
                   │ Overlay queue │
                   ╰──────┬────────╯
                          ▼
                   ╭───────────────╮
                   │ Admin replay  │
                   ╰───────────────╯
```

## Task List

### Phase 1: Foundation

## Task 1: Bootstrap the Phoenix app

**Description:** Create the base Phoenix 1.8 + LiveView project with Ecto enabled so future tasks land into a running application rather than a blank repo.

**Acceptance criteria:**
- [x] The Phoenix app boots locally.
- [x] LiveView is enabled and the default landing page renders.
- [x] `mix test` runs successfully on the fresh app.

**Verification:**
- [x] Run `mix precommit`
- [x] Run `mix phx.server`
- [x] Manual check: visit `/` and confirm the app renders

**Dependencies:** None

**Files likely touched:**
- `mix.exs`
- `config/config.exs`
- `lib/...`
- `test/...`

**Estimated scope:** M

## Task 2: Configure SQLite and repo wiring

**Description:** Replace the default database adapter if needed, wire up SQLite, and ensure local dev/test databases are correctly configured.

**Acceptance criteria:**
- [x] The app uses SQLite for development and test.
- [x] `mix ecto.create` and `mix ecto.migrate` work.
- [x] Repo configuration is stable in both dev and test.

**Verification:**
- [x] Run `mix ecto.create`
- [x] Run `mix ecto.migrate`
- [x] Run `mix precommit`

**Dependencies:** Task 1

**Files likely touched:**
- `mix.exs`
- `config/dev.exs`
- `config/test.exs`
- `config/runtime.exs`

**Estimated scope:** S

## Task 3: Add runtime env config and `.env` contract

**Description:** Define the required environment variables for Mayar, overlay access, admin auth, and app URL configuration so later tasks share a stable contract.

**Acceptance criteria:**
- [x] Runtime config includes Mayar API base URL, Mayar API key, overlay token, admin username, admin password, and app base URL.
- [x] Development setup is documented around `source .env`.
- [x] Missing required production config fails clearly.

**Verification:**
- [x] Manual check: app boots with values loaded from environment
- [x] Manual check: app reports a clear config error when a required value is missing in prod mode

**Dependencies:** Task 1

**Files likely touched:**
- `config/runtime.exs`
- `.env.example`
- `README.md`

**Estimated scope:** S

## Task 4: Add route placeholders and app surfaces

**Description:** Create empty surfaces for donor, overlay, admin, and webhook endpoints so later slices plug into stable routes.

**Acceptance criteria:**
- [x] `/donate` resolves.
- [x] `/overlay/:token` resolves.
- [x] `/admin` resolves.
- [x] `/webhooks/mayar` resolves for POST requests.

**Verification:**
- [x] Run `mix phx.routes`
- [x] Manual check: visit the LiveView routes and confirm they mount

**Dependencies:** Task 1

**Files likely touched:**
- `lib/..._web/router.ex`
- `lib/..._web/live/...`
- `lib/..._web/controllers/...`

**Estimated scope:** S

### Checkpoint: Foundation

- [x] `mix precommit` passes
- [x] `mix ecto.create && mix ecto.migrate` succeeds
- [x] The app boots with all placeholder routes present

### Phase 2: Data Model

## Task 5: Create the donations migration

**Description:** Add the persisted donation model required by the PRD, including a unique Mayar transaction identifier and alert state.

**Acceptance criteria:**
- [ ] `donations` table exists with `mayar_transaction_id`, `donor_name`, `amount`, `message`, `status`, `alerted`, and timestamps.
- [ ] `mayar_transaction_id` has a unique index.
- [ ] `status` defaults are sensible for pending donations.

**Verification:**
- [ ] Run `mix ecto.migrate`
- [ ] Inspect schema with a migration test or SQL query

**Dependencies:** Task 2

**Files likely touched:**
- `priv/repo/migrations/*_create_donations.exs`

**Estimated scope:** XS

## Task 6: Add the Donation schema and changeset

**Description:** Define the Ecto schema, validations, and status constraints used by the rest of the system.

**Acceptance criteria:**
- [ ] Required fields are validated.
- [ ] Only allowed statuses are accepted.
- [ ] Amount is stored as an integer in IDR.

**Verification:**
- [ ] Run schema tests
- [ ] Manual check: invalid attrs are rejected in changeset tests

**Dependencies:** Task 5

**Files likely touched:**
- `lib/.../donations/donation.ex`
- `test/.../donation_test.exs`

**Estimated scope:** S

## Task 7: Add Donations context functions

**Description:** Create the core data API used by the donor flow, webhook ingestion, overlay recovery, and admin listing.

**Acceptance criteria:**
- [ ] Can create a pending donation at QR generation time.
- [ ] Can mark a donation paid by Mayar transaction ID.
- [ ] Can fetch paid/unalerted donations for overlay recovery.
- [ ] Can mark a donation alerted.
- [ ] Can list all donations for admin.

**Verification:**
- [ ] Run context tests for create, update, list, and recovery queries

**Dependencies:** Task 6

**Files likely touched:**
- `lib/.../donations.ex`
- `test/.../donations_test.exs`

**Estimated scope:** M

## Task 8: Add persistence tests for dedupe and state transitions

**Description:** Lock down the data behavior the rest of the app depends on, especially webhook idempotency and alert recovery.

**Acceptance criteria:**
- [ ] Duplicate `mayar_transaction_id` values are rejected.
- [ ] Pending donations can become paid.
- [ ] Paid donations can be marked alerted.
- [ ] Recovery query only returns paid and unalerted donations.

**Verification:**
- [ ] Run `mix test test/.../donations_test.exs`

**Dependencies:** Task 7

**Files likely touched:**
- `test/.../donations_test.exs`

**Estimated scope:** S

### Checkpoint: Data Model

- [ ] Persistence behavior is covered by tests
- [ ] App still boots and migrations remain clean
- [ ] `mix precommit` passed

### Phase 3: Mayar Integration Contract

## Task 9: Validate the Mayar webhook authenticity model

**Description:** Resolve the biggest documented gap: the Mayar docs show payloads and management endpoints but do not document a webhook signature scheme. This task confirms whether one exists in practice or whether the system must validate authenticity another way.

**Acceptance criteria:**
- [ ] Review the Mayar docs and dashboard settings for signature/header support.
- [ ] If available, document the exact header and verification algorithm.
- [ ] If unavailable, choose and document the fallback trust model for MVP.

**Verification:**
- [ ] Write the result into project docs or code comments
- [ ] Human review confirms the chosen security model is acceptable

**Dependencies:** Task 3

**Files likely touched:**
- `docs/PLAN.md`
- `README.md`

**Estimated scope:** XS

## Task 10: Define the Mayar client interface

**Description:** Freeze the internal contract used by the app before implementing the HTTP client, especially because Mayar’s QR response shape is not fully documented in the public collection.

**Acceptance criteria:**
- [ ] Internal function signature is defined for dynamic QR creation.
- [ ] Expected normalized success payload is documented.
- [ ] Unknown or undocumented response fields are explicitly marked as to-be-confirmed.

**Verification:**
- [ ] Human review of client contract

**Dependencies:** Task 3

**Files likely touched:**
- `lib/.../mayar/client.ex`
- `docs/PLAN.md`

**Estimated scope:** XS

## Task 11: Implement the Mayar API client

**Description:** Implement the HTTP client around Mayar’s authenticated endpoints for dynamic QR generation and any follow-up lookup needed for live confirmation.

**Acceptance criteria:**
- [ ] The client calls the configured Mayar base URL using the API key.
- [ ] QR creation requests accept an amount and return normalized app data.
- [ ] Errors are normalized into app-friendly return tuples.

**Verification:**
- [ ] Run client tests with mocked HTTP responses

**Dependencies:** Task 10

**Files likely touched:**
- `mix.exs`
- `lib/.../mayar/client.ex`
- `test/.../mayar/client_test.exs`

**Estimated scope:** M

## Task 12: Add Mayar client tests

**Description:** Cover the success and failure paths so later UI work can rely on the client contract without live API access.

**Acceptance criteria:**
- [ ] Success response is parsed correctly.
- [ ] API errors return normalized failures.
- [ ] Network failures return normalized failures.

**Verification:**
- [ ] Run `mix test test/.../mayar/client_test.exs`

**Dependencies:** Task 11

**Files likely touched:**
- `test/.../mayar/client_test.exs`

**Estimated scope:** S

## Task 13: Define webhook payload parsing rules

**Description:** Isolate how `payment.received` maps into local donation updates using the payload fields documented by Mayar.

**Acceptance criteria:**
- [ ] The parser extracts event name, transaction ID, donor name, amount, and transaction status.
- [ ] Non-`payment.received` events are ignored safely.
- [ ] Missing critical fields are rejected.

**Verification:**
- [ ] Run parser tests from example payloads

**Dependencies:** Task 9

**Files likely touched:**
- `lib/.../mayar/webhook.ex`
- `test/.../mayar/webhook_test.exs`

**Estimated scope:** S

### Checkpoint: Integration Contract

- [ ] Mayar client contract is fixed
- [ ] Webhook authenticity strategy is explicitly decided
- [ ] Parser behavior is documented and tested

### Phase 4: Donor Flow

## Task 14: Build donor form UI

**Description:** Add the public donation page with name, preset amounts, custom amount entry, and optional message.

**Acceptance criteria:**
- [ ] Name is required.
- [ ] User can choose preset amounts or enter a custom amount.
- [ ] Message is optional.
- [ ] Layout works on mobile.

**Verification:**
- [ ] Run LiveView tests for validation
- [ ] Manual check in a narrow mobile viewport

**Dependencies:** Task 4

**Files likely touched:**
- `lib/..._web/live/donate_live.ex`
- `lib/..._web/live/donate_live.html.heex`
- `test/.../donate_live_test.exs`

**Estimated scope:** M

## Task 15: Wire donor submission to pending donation creation and QR generation

**Description:** Connect the donor form to the Donations context and Mayar client so each submission creates a local pending row and requests a fresh QR.

**Acceptance criteria:**
- [ ] A successful form submission creates a pending donation row.
- [ ] The app requests a QR from Mayar using the configured client.
- [ ] The LiveView transitions into a payment state with the returned QR data.

**Verification:**
- [ ] Run LiveView tests for successful submission
- [ ] Manual check: submit the form and inspect the DB row

**Dependencies:** Task 7, Task 11, Task 14

**Files likely touched:**
- `lib/..._web/live/donate_live.ex`
- `lib/.../donations.ex`
- `test/.../donate_live_test.exs`

**Estimated scope:** M

## Task 16: Render payment and waiting states on the donor page

**Description:** Show the QR, donor details, amount, and a clear waiting-for-payment state after successful submission.

**Acceptance criteria:**
- [ ] The payment state renders the QR and amount.
- [ ] The donor sees that payment confirmation is pending.
- [ ] The page is still usable on mobile.

**Verification:**
- [ ] Manual check: successful form submit shows payment screen

**Dependencies:** Task 15

**Files likely touched:**
- `lib/..._web/live/donate_live.html.heex`

**Estimated scope:** S

## Task 17: Add live update from pending to paid on donor page

**Description:** When a payment is confirmed, the donor page should transition from waiting to success without a page refresh.

**Acceptance criteria:**
- [ ] Confirmed payments update the donor page in real time.
- [ ] The success state is distinct from the waiting state.
- [ ] The page handles reconnects without showing stale data indefinitely.

**Verification:**
- [ ] Manual check: simulate a webhook after page creation and watch the page update
- [ ] Add at least one LiveView test covering the transition if practical

**Dependencies:** Task 15, Task 19

**Files likely touched:**
- `lib/..._web/live/donate_live.ex`
- `lib/..._web/live/donate_live.html.heex`
- `test/.../donate_live_test.exs`

**Estimated scope:** M

### Phase 5: Webhook Ingestion

## Task 18: Implement the webhook controller shell

**Description:** Add the POST endpoint plumbing that receives raw Mayar webhook requests and dispatches to the parser and persistence layer.

**Acceptance criteria:**
- [ ] The endpoint accepts JSON POSTs.
- [ ] Unsupported payloads return an explicit error.
- [ ] The controller is isolated from business logic.

**Verification:**
- [ ] Run controller tests for basic request handling

**Dependencies:** Task 4, Task 13

**Files likely touched:**
- `lib/..._web/controllers/mayar_webhook_controller.ex`
- `test/.../mayar_webhook_controller_test.exs`

**Estimated scope:** S

## Task 19: Persist paid donations before broadcasting

**Description:** Implement the PRD’s core reliability guarantee: update the DB first, then broadcast the payment event only after persistence succeeds.

**Acceptance criteria:**
- [ ] A valid `payment.received` webhook marks the matching donation as paid.
- [ ] The donation update happens before PubSub broadcast.
- [ ] Duplicate Mayar transaction deliveries do not create duplicate rows or duplicate state transitions.

**Verification:**
- [ ] Run webhook tests for valid payload, duplicate payload, and write-before-broadcast behavior

**Dependencies:** Task 7, Task 13, Task 18

**Files likely touched:**
- `lib/.../mayar/webhook_handler.ex`
- `lib/..._web/controllers/mayar_webhook_controller.ex`
- `test/.../mayar_webhook_controller_test.exs`

**Estimated scope:** M

## Task 20: Enforce the chosen webhook authenticity strategy

**Description:** Apply the security model chosen in Task 9, whether that becomes documented signature validation or a validated fallback approach.

**Acceptance criteria:**
- [ ] Invalid webhook requests are rejected.
- [ ] Only accepted webhook requests can reach persistence.
- [ ] The implementation matches the documented Mayar capability or fallback decision.

**Verification:**
- [ ] Run security-focused controller tests
- [ ] Human review of the chosen mechanism

**Dependencies:** Task 9, Task 18

**Files likely touched:**
- `lib/.../mayar/webhook_auth.ex`
- `lib/..._web/controllers/mayar_webhook_controller.ex`
- `test/.../mayar_webhook_controller_test.exs`

**Estimated scope:** M

## Task 21: Add webhook ingestion tests

**Description:** Cover the behavior the PRD explicitly calls out: authenticity, dedupe, and persistence ordering.

**Acceptance criteria:**
- [ ] Valid request path is covered.
- [ ] Invalid or missing auth is covered.
- [ ] Duplicate delivery is covered.
- [ ] DB-write-before-broadcast is covered.

**Verification:**
- [ ] Run `mix test test/.../mayar_webhook_controller_test.exs`

**Dependencies:** Task 19, Task 20

**Files likely touched:**
- `test/.../mayar_webhook_controller_test.exs`

**Estimated scope:** S

### Checkpoint: Payment Lifecycle

- [ ] Donor can create a pending donation and see a QR
- [ ] Webhook can mark that donation paid exactly once
- [ ] Donor page can update to success in real time

### Phase 6: Overlay Queue

## Task 22: Create overlay LiveView with token gate

**Description:** Add the OBS overlay surface and restrict it using the configured non-guessable token.

**Acceptance criteria:**
- [ ] `/overlay/:token` mounts with the correct token.
- [ ] Invalid token requests are rejected.
- [ ] The LiveView renders an empty state cleanly.

**Verification:**
- [ ] Run route or LiveView tests
- [ ] Manual check with valid and invalid token values

**Dependencies:** Task 3, Task 4

**Files likely touched:**
- `lib/..._web/live/overlay_live.ex`
- `lib/..._web/live/overlay_live.html.heex`
- `test/.../overlay_live_test.exs`

**Estimated scope:** S

## Task 23: Seed overlay queue from paid/unalerted donations

**Description:** Implement restart recovery by loading missed alerts from the DB on mount.

**Acceptance criteria:**
- [ ] Overlay mount queries paid and unalerted donations.
- [ ] Seeded alerts enter the queue in a stable order.
- [ ] Already alerted donations are not replayed automatically.

**Verification:**
- [ ] Run overlay recovery tests

**Dependencies:** Task 7, Task 22

**Files likely touched:**
- `lib/..._web/live/overlay_live.ex`
- `test/.../overlay_live_test.exs`

**Estimated scope:** S

## Task 24: Implement sequential alert queue behavior

**Description:** Keep exactly one active alert at a time and queue new donations behind it.

**Acceptance criteria:**
- [ ] Simultaneous donations do not overlap visually.
- [ ] New alerts received while one is visible are queued.
- [ ] Queue ordering is deterministic.

**Verification:**
- [ ] Run overlay queue tests

**Dependencies:** Task 19, Task 23

**Files likely touched:**
- `lib/..._web/live/overlay_live.ex`
- `test/.../overlay_live_test.exs`

**Estimated scope:** M

## Task 25: Add auto-dismiss and alert acknowledgement

**Description:** Dismiss each alert after 5 seconds and mark it alerted only after it begins or completes display, consistent with the chosen semantics.

**Acceptance criteria:**
- [ ] Each alert dismisses automatically after 5 seconds.
- [ ] Each displayed donation is marked alerted in the DB.
- [ ] After dismissal, the next queued alert begins automatically.

**Verification:**
- [ ] Run overlay tests using message timers

**Dependencies:** Task 24

**Files likely touched:**
- `lib/..._web/live/overlay_live.ex`
- `test/.../overlay_live_test.exs`

**Estimated scope:** M

## Task 26: Build the minimal OBS-ready alert UI

**Description:** Render the actual overlay card with donor name, amount, and optional message in a stream-friendly minimal design.

**Acceptance criteria:**
- [ ] Name and amount are always visible.
- [ ] Message renders only when present.
- [ ] Styling is minimal and readable on stream.

**Verification:**
- [ ] Manual OBS-style browser test in desktop browser

**Dependencies:** Task 25

**Files likely touched:**
- `lib/..._web/live/overlay_live.html.heex`
- `assets/css/app.css`

**Estimated scope:** S

## Task 27: Add overlay queue tests

**Description:** Lock down queue ordering, recovery, dismissal, and alerted marking.

**Acceptance criteria:**
- [ ] Queue ordering is tested.
- [ ] Recovery seed is tested.
- [ ] Auto-dismiss progression is tested.
- [ ] Alert acknowledgement is tested.

**Verification:**
- [ ] Run `mix test test/.../overlay_live_test.exs`

**Dependencies:** Task 25

**Files likely touched:**
- `test/.../overlay_live_test.exs`

**Estimated scope:** S

### Checkpoint: Overlay

- [ ] Paid donations appear in the overlay
- [ ] Alerts never overlap
- [ ] Restart recovery replays missed alerts

### Phase 7: Admin Replay

## Task 28: Add basic auth protection for admin

**Description:** Protect the admin area with simple credentials from environment config.

**Acceptance criteria:**
- [ ] `/admin` requires basic auth.
- [ ] Invalid credentials are rejected.
- [ ] Valid credentials allow access.

**Verification:**
- [ ] Run controller or plug tests
- [ ] Manual check in browser

**Dependencies:** Task 3, Task 4

**Files likely touched:**
- `lib/..._web/router.ex`
- `lib/..._web/plugs/...`
- `test/...`

**Estimated scope:** S

## Task 29: Build the admin donations list

**Description:** Show the streamer a simple functional view of all donations, statuses, and alert state.

**Acceptance criteria:**
- [ ] Donations are listed in a stable order.
- [ ] Status and alerted state are visible.
- [ ] The page is usable without extra admin tooling.

**Verification:**
- [ ] Run LiveView tests or manual check with seed data

**Dependencies:** Task 7, Task 28

**Files likely touched:**
- `lib/..._web/live/admin_live.ex`
- `lib/..._web/live/admin_live.html.heex`
- `test/.../admin_live_test.exs`

**Estimated scope:** S

## Task 30: Implement admin replay rebroadcast

**Description:** Add a per-donation replay action that sends the donation back through the overlay without resetting historical donation state.

**Acceptance criteria:**
- [ ] Replay sends an overlay event for the selected donation.
- [ ] Replay does not mutate `alerted` back to false.
- [ ] Replayed alerts show again in the overlay.

**Verification:**
- [ ] Run admin replay tests
- [ ] Manual check with overlay open

**Dependencies:** Task 24, Task 29

**Files likely touched:**
- `lib/..._web/live/admin_live.ex`
- `test/.../admin_live_test.exs`

**Estimated scope:** M

## Task 31: Add admin tests

**Description:** Cover auth and replay so the control surface is stable.

**Acceptance criteria:**
- [ ] Admin auth behavior is covered.
- [ ] Replay action behavior is covered.

**Verification:**
- [ ] Run `mix test test/.../admin_live_test.exs`

**Dependencies:** Task 30

**Files likely touched:**
- `test/.../admin_live_test.exs`

**Estimated scope:** S

### Phase 8: Operations and Polish

## Task 32: Add logging around donation lifecycle events

**Description:** Log QR creation, webhook acceptance/rejection, duplicate deliveries, and replay events without leaking secrets.

**Acceptance criteria:**
- [ ] Success and failure states are visible in logs.
- [ ] Secrets are not logged.
- [ ] Duplicate webhook deliveries are distinguishable.

**Verification:**
- [ ] Manual check of logs during local flow tests

**Dependencies:** Task 19, Task 30

**Files likely touched:**
- `lib/.../mayar/...`
- `lib/..._web/live/admin_live.ex`

**Estimated scope:** S

## Task 33: Document setup and deployment details

**Description:** Capture enough setup information that the app can be configured, exposed publicly, and connected to Mayar without tribal knowledge.

**Acceptance criteria:**
- [ ] `.env` variables are documented.
- [ ] Mayar webhook registration flow is documented.
- [ ] Overlay and admin URLs are documented.
- [ ] Recovery behavior and webhook retry caveats are documented.

**Verification:**
- [ ] Manual doc review

**Dependencies:** Task 32

**Files likely touched:**
- `README.md`
- `docs/...`

**Estimated scope:** S

## Task 34: Final verification pass

**Description:** Run the full smoke test of the MVP before first deployment.

**Acceptance criteria:**
- [ ] Tests pass.
- [ ] Donor flow works locally.
- [ ] Webhook updates the donor page and overlay.
- [ ] Admin replay works.

**Verification:**
- [ ] Run `mix precommit`
- [ ] Run full manual smoke test with sandbox or mocked Mayar flow

**Dependencies:** Task 33

**Files likely touched:**
- No code changes required unless fixes are found

**Estimated scope:** XS

## Parallelization Opportunities

- After Task 8, one agent can handle Tasks 9-13 while another prepares donor UI shell work in Task 14.
- After Task 21, donor live-update work in Task 17 and overlay work in Tasks 22-27 can proceed in parallel.
- After Task 27, admin work in Tasks 28-31 and documentation/logging work in Tasks 32-33 can proceed in parallel.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Mayar webhook authenticity mechanism is undocumented | High | Resolve it in Task 9 before finalizing webhook security implementation |
| Mayar QR creation response shape is under-documented in the public collection | Medium | Freeze an internal client contract in Task 10 and confirm against sandbox responses |
| Donor live-update requires correlating a browser session with a later webhook event | Medium | Store local donation rows at QR creation time and subscribe the donor page to updates by local donation ID or Mayar transaction ID |
| Overlay queue edge cases can create duplicate or overlapping alerts | Medium | Keep queue logic small, test recovery and timing behavior directly, and avoid extra queue infrastructure in MVP |
| Webhook retries and delivery timing are not fully documented | Medium | Document observed behavior during sandbox testing and rely on DB dedupe and recovery queue |

## Open Questions

- Does Mayar expose any undocumented webhook signature header in the dashboard or live requests, or must MVP authenticity use a fallback strategy?
- What exact response fields does `POST /qrcode/create` return in practice for a successful dynamic QR creation?
- Should `transactionStatus = paid` or `status = SUCCESS` be treated as the primary condition for donation confirmation, or both?

## Suggested LLM Handoff Order

1. Tasks 1-4 to establish the app and route skeleton.
2. Tasks 5-8 to land the persistence model.
3. Tasks 9-13 to lock the Mayar integration contract.
4. Tasks 14-17 for the donor flow.
5. Tasks 18-21 for webhook ingestion.
6. Tasks 22-27 for overlay recovery and queue behavior.
7. Tasks 28-31 for admin replay.
8. Tasks 32-34 for operational polish and final verification.

## Planning Verification

- [ ] Every task has acceptance criteria.
- [ ] Every task has a verification step.
- [ ] Dependencies are ordered from foundation to feature slices.
- [ ] No task is intentionally XL-sized.
- [ ] Checkpoints exist between major phases.
- [ ] Human review is still needed before implementation begins.
