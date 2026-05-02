# Task List: Livestream Donation System

## Phase 1: Foundation

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

## Phase 2: Data Model

## Task 5: Create the donations migration

**Description:** Add the persisted donation model required by the PRD, including a unique Mayar transaction identifier and alert state.

**Acceptance criteria:**
- [x] `donations` table exists with `mayar_transaction_id`, `donor_name`, `amount`, `message`, `status`, `alerted`, and timestamps.
- [x] `mayar_transaction_id` has a unique index.
- [x] `status` defaults are sensible for pending donations.

**Verification:**
- [x] Run `mix ecto.migrate`
- [x] Inspect schema with a migration test or SQL query

**Dependencies:** Task 2

**Files likely touched:**
- `priv/repo/migrations/*_create_donations.exs`

**Estimated scope:** XS

## Task 6: Add the Donation schema and changeset

**Description:** Define the Ecto schema, validations, and status constraints used by the rest of the system.

**Acceptance criteria:**
- [x] Required fields are validated.
- [x] Only allowed statuses are accepted.
- [x] Amount is stored as an integer in IDR.

**Verification:**
- [x] Run schema tests
- [x] Manual check: invalid attrs are rejected in changeset tests

**Dependencies:** Task 5

**Files likely touched:**
- `lib/.../donations/donation.ex`
- `test/.../donation_test.exs`

**Estimated scope:** S

## Task 7: Add Donations context functions

**Description:** Create the core data API used by the donor flow, webhook ingestion, overlay recovery, and admin listing.

**Acceptance criteria:**
- [x] Can create a pending donation at QR generation time.
- [x] Can mark a donation paid by Mayar transaction ID.
- [x] Can fetch paid/unalerted donations for overlay recovery.
- [x] Can mark a donation alerted.
- [x] Can list all donations for admin.

**Verification:**
- [x] Run context tests for create, update, list, and recovery queries

**Dependencies:** Task 6

**Files likely touched:**
- `lib/.../donations.ex`
- `test/.../donations_test.exs`

**Estimated scope:** M

## Task 8: Add persistence tests for dedupe and state transitions

**Description:** Lock down the data behavior the rest of the app depends on, especially webhook idempotency and alert recovery.

**Acceptance criteria:**
- [x] Duplicate `mayar_transaction_id` values are rejected.
- [x] Pending donations can become paid.
- [x] Paid donations can be marked alerted.
- [x] Recovery query only returns paid and unalerted donations.

**Verification:**
- [x] Run `mix test test/.../donations_test.exs`

**Dependencies:** Task 7

**Files likely touched:**
- `test/.../donations_test.exs`

**Estimated scope:** S

### Checkpoint: Data Model

- [x] Persistence behavior is covered by tests
- [x] App still boots and migrations remain clean
- [x] `mix precommit` passed

## Phase 3: Mayar Integration Contract

## Task 9: Validate the Mayar webhook authenticity model

**Description:** Resolve the biggest documented gap: the Mayar docs show payloads and management endpoints but do not document a webhook signature scheme. This task confirms whether one exists in practice or whether the system must validate authenticity another way.

**Acceptance criteria:**
- [x] Review the Mayar docs and dashboard settings for signature/header support.
- [x] If available, document the exact header and verification algorithm.
- [x] If unavailable, choose and document the fallback trust model for MVP.

**Verification:**
- [x] Write the result into project docs or code comments
- [x] Human review confirms the chosen security model is acceptable

**Dependencies:** Task 3

**Files likely touched:**
- `docs/plans/context.md`
- `README.md`
- `docs/decisions/ADR-008-mayar-webhook-authenticity-fallback.md`

**Estimated scope:** XS

## Task 10: Define the Mayar client interface

**Description:** Freeze the internal contract used by the app before implementing the HTTP client, especially because Mayar’s QR response shape is not fully documented in the public collection.

**Acceptance criteria:**
- [x] Internal function signature is defined for dynamic QR creation.
- [x] Expected normalized success payload is documented.
- [x] Unknown or undocumented response fields are explicitly marked as to-be-confirmed.

**Client contract (internal):**
- `Donatex.Mayar.Client.create_qr(amount_idr)` where `amount_idr` is a positive integer.
- Returns `{:ok, %Donatex.Mayar.Client.DynamicQr{...}}` or `{:error, reason}`.

**Normalized success payload:**
- `%Donatex.Mayar.Client.DynamicQr{`
  - `mayar_transaction_id :: String.t()` (used for webhook dedupe + donation correlation)
  - `amount :: pos_integer()` (IDR)
  - `qr_image_url :: String.t()` (HTTP(S) URL or `data:` URL usable by the donor page)
  - `expires_at :: DateTime.t() | nil` (optional)
  - `}`

**Normalized error reasons (current set, may expand):**
- `:invalid_amount | :not_implemented | :unauthorized | :rate_limited | :bad_request | :upstream_error | :network_error | {:unexpected_response, term()}`

**To be confirmed against real/sandbox `POST /qrcode/create` responses:**
- Whether Mayar uses `data.transactionId`, `data.id`, or both. The client supports both; missing ids are treated as `{:unexpected_response, body}`.
- Whether Mayar returns a ready-to-render QR image URL vs only QR content that must be rendered client-side
- Whether an expiry timestamp is returned and in what field/format

**Verification:**
- [x] Human review of client contract

**Dependencies:** Task 3

**Files likely touched:**
- `lib/.../mayar/client.ex`
- `docs/plans/context.md`

**Estimated scope:** XS

## Task 11: Implement the Mayar API client

**Description:** Implement the HTTP client around Mayar’s authenticated endpoints for dynamic QR generation and any follow-up lookup needed for live confirmation.

**Acceptance criteria:**
- [x] The client calls the configured Mayar base URL using the API key.
- [x] QR creation requests accept an amount and return normalized app data.
- [x] Errors are normalized into app-friendly return tuples.

**Verification:**
- [x] Run client tests with mocked HTTP responses

**Dependencies:** Task 10

**Files likely touched:**
- `mix.exs`
- `lib/.../mayar/client.ex`
- `test/.../mayar/client_test.exs`

**Estimated scope:** M

## Task 12: Add Mayar client tests

**Description:** Cover the success and failure paths so later UI work can rely on the client contract without live API access.

**Acceptance criteria:**
- [x] Success response is parsed correctly.
- [x] API errors return normalized failures.
- [x] Network failures return normalized failures.

**Verification:**
- [x] Run `mix test test/.../mayar/client_test.exs`

**Dependencies:** Task 11

**Files likely touched:**
- `test/.../mayar/client_test.exs`

**Estimated scope:** S

## Task 13: Define webhook payload parsing rules

**Description:** Isolate how `payment.received` maps into local donation updates using the payload fields documented by Mayar.

**Acceptance criteria:**
- [x] The parser extracts event name, transaction ID, donor name, amount, and transaction status.
- [x] Non-`payment.received` events are ignored safely.
- [x] Missing critical fields are rejected.

**Verification:**
- [x] Run parser tests from example payloads

**Dependencies:** Task 9

**Files likely touched:**
- `lib/.../mayar/webhook.ex`
- `test/.../mayar/webhook_test.exs`

**Estimated scope:** S

### Checkpoint: Integration Contract

- [x] Mayar client contract is fixed
- [x] Webhook authenticity strategy is explicitly decided
- [x] Parser behavior is documented and tested

## Phase 4: Donor Flow

## Task 14: Build donor form UI

**Description:** Add the public donation page with name, preset amounts, custom amount entry, and optional message.

**Acceptance criteria:**
- [x] Name is required.
- [x] User can choose preset amounts or enter a custom amount.
- [x] Message is optional.
- [x] Layout works on mobile.

**Verification:**
- [x] Run LiveView tests for validation
- [x] Manual check in a narrow mobile viewport

**Dependencies:** Task 4

**Files likely touched:**
- `lib/..._web/live/donate_live.ex`
- `lib/..._web/live/donate_live.html.heex`
- `test/.../donate_live_test.exs`

**Estimated scope:** M

## Task 15: Wire donor submission to pending donation creation and QR generation

**Description:** Connect the donor form to the Donations context and Mayar client so each submission creates a local pending row and requests a fresh QR.

**Acceptance criteria:**
- [x] A successful form submission creates a pending donation row.
- [x] The app requests a QR from Mayar using the configured client.
- [x] The LiveView transitions into a payment state with the returned QR data.

**Verification:**
- [x] Run feature tests for successful submission
- [x] Manual check: submit the form and inspect the DB row (optional)

**Dependencies:** Task 7, Task 11, Task 14

**Files likely touched:**
- `lib/..._web/live/donate_live.ex`
- `lib/.../donations.ex`
- `test/.../donate_live_test.exs`

**Estimated scope:** M

## Task 16: Render payment and waiting states on the donor page

**Description:** Show the QR, donor details, amount, and a clear waiting-for-payment state after successful submission.

**Acceptance criteria:**
- [x] The payment state renders the QR and amount.
- [x] The donor sees that payment confirmation is pending.
- [x] The page is still usable on mobile.

**Verification:**
- [x] Manual check: successful form submit shows payment screen

**Dependencies:** Task 15

**Files likely touched:**
- `lib/..._web/live/donate_live.html.heex`

**Estimated scope:** S

## Task 17: Add live update from pending to paid on donor page

**Description:** When a payment is confirmed, the donor page should transition from waiting to success without a page refresh.

**Acceptance criteria:**
- [x] Confirmed payments update the donor page in real time.
- [x] The success state is distinct from the waiting state.
- [x] The page handles reconnects without showing stale data indefinitely.

**Verification:**
- [x] Manual check: simulate a webhook after page creation and watch the page update
- [x] Feature test covers the transition

**Dependencies:** Task 15, Task 19

**Files likely touched:**
- `lib/..._web/live/donate_live.ex`
- `lib/..._web/live/donate_live.html.heex`
- `test/.../donate_live_test.exs`

**Estimated scope:** M

## Phase 5: Webhook Ingestion

## Task 18: Implement the webhook controller shell

**Description:** Add the POST endpoint plumbing that receives raw Mayar webhook requests and dispatches to the parser and persistence layer.

**Acceptance criteria:**
- [x] The endpoint accepts JSON POSTs.
- [x] Unsupported payloads are ignored safely while returning a successful response.
- [x] The controller uses dedicated parser/auth modules and keeps logic small.

**Verification:**
- [x] Run controller tests for basic request handling

**Dependencies:** Task 4, Task 13

**Files likely touched:**
- `lib/..._web/controllers/mayar_webhook_controller.ex`
- `test/.../mayar_webhook_controller_test.exs`

**Estimated scope:** S

## Task 19: Persist paid donations before broadcasting

**Description:** Implement the PRD’s core reliability guarantee: update the DB first, then broadcast the payment event only after persistence succeeds.

**Acceptance criteria:**
- [x] A valid `payment.received` webhook marks the matching donation as paid.
- [x] The donation update happens before PubSub broadcast.
- [x] Duplicate Mayar transaction deliveries do not create duplicate rows or duplicate state transitions.

**Verification:**
- [x] Run webhook tests for valid payload, duplicate payload, and write-before-broadcast behavior

**Dependencies:** Task 7, Task 13, Task 18

**Files likely touched:**
- `lib/.../mayar/webhook_handler.ex`
- `lib/..._web/controllers/mayar_webhook_controller.ex`
- `test/.../mayar_webhook_controller_test.exs`

**Estimated scope:** M

## Task 20: Enforce the chosen webhook authenticity strategy

**Description:** Apply the security model chosen in Task 9, whether that becomes documented signature validation or a validated fallback approach.

**Acceptance criteria:**
- [x] Invalid webhook requests are rejected.
- [x] Only accepted webhook requests can reach persistence.
- [x] The implementation matches the documented Mayar capability or fallback decision.

**Verification:**
- [x] Run security-focused controller tests
- [x] Human review of the chosen mechanism

**Dependencies:** Task 9, Task 18

**Files likely touched:**
- `lib/.../mayar/webhook_auth.ex`
- `lib/..._web/controllers/mayar_webhook_controller.ex`
- `test/.../mayar_webhook_controller_test.exs`

**Estimated scope:** M

## Task 21: Add webhook ingestion tests

**Description:** Cover the behavior the PRD explicitly calls out: authenticity, dedupe, and persistence ordering.

**Acceptance criteria:**
- [x] Valid request path is covered.
- [x] Invalid or missing auth is covered.
- [x] Duplicate delivery is covered.
- [x] DB-write-before-broadcast is covered.

**Verification:**
- [x] Run `mix test test/.../mayar_webhook_controller_test.exs`

**Dependencies:** Task 19, Task 20

**Files likely touched:**
- `test/.../mayar_webhook_controller_test.exs`

**Estimated scope:** S

### Checkpoint: Payment Lifecycle

- [x] Donor can create a pending donation and see a QR
- [x] Webhook can mark that donation paid exactly once
- [x] Donor page can update to success in real time

## Phase 6: Overlay Queue

## Task 22: Create overlay LiveView with token gate

**Description:** Add the OBS overlay surface and restrict it using the configured non-guessable token.

**Acceptance criteria:**
- [x] `/overlay/:token` mounts with the correct token.
- [x] Invalid token requests are rejected.
- [x] The LiveView renders an empty state cleanly.

**Verification:**
- [x] Run route or LiveView tests
- [x] Manual check with valid and invalid token values

**Dependencies:** Task 3, Task 4

**Files likely touched:**
- `lib/..._web/live/overlay_live.ex`
- `lib/..._web/live/overlay_live.html.heex`
- `test/.../overlay_live_test.exs`

**Estimated scope:** S

## Task 23: Seed overlay queue from paid/unalerted donations

**Description:** Implement restart recovery by loading missed alerts from the DB on mount.

**Acceptance criteria:**
- [x] Overlay mount queries paid and unalerted donations.
- [x] Seeded alerts enter the queue in a stable order.
- [x] Already alerted donations are not replayed automatically.

**Verification:**
- [x] Run overlay recovery tests

**Dependencies:** Task 7, Task 22

**Files likely touched:**
- `lib/..._web/live/overlay_live.ex`
- `test/.../overlay_live_test.exs`

**Estimated scope:** S

## Task 24: Implement sequential alert queue behavior

**Description:** Keep exactly one active alert at a time and queue new donations behind it.

**Acceptance criteria:**
- [x] Simultaneous donations do not overlap visually.
- [x] New alerts received while one is visible are queued.
- [x] Queue ordering is deterministic.

**Verification:**
- [x] Run overlay queue tests

**Dependencies:** Task 19, Task 23

**Files likely touched:**
- `lib/..._web/live/overlay_live.ex`
- `test/.../overlay_live_test.exs`

**Estimated scope:** M

## Task 25: Add auto-dismiss and alert acknowledgement

**Description:** Dismiss each alert after 5 seconds and mark it alerted only after it begins or completes display, consistent with the chosen semantics.

**Acceptance criteria:**
- [x] Each alert dismisses automatically after 5 seconds.
- [x] Each displayed donation is marked alerted in the DB.
- [x] After dismissal, the next queued alert begins automatically.

**Verification:**
- [x] Run overlay tests using message timers

**Dependencies:** Task 24

**Files likely touched:**
- `lib/..._web/live/overlay_live.ex`
- `test/.../overlay_live_test.exs`

**Estimated scope:** M

## Task 26: Build the minimal OBS-ready alert UI

**Description:** Render the actual overlay card with donor name, amount, and optional message in a stream-friendly minimal design.

**Acceptance criteria:**
- [x] Name and amount are always visible.
- [x] Message renders only when present.
- [x] Styling is minimal and readable on stream.

**Verification:**
- [x] Manual OBS-style browser test in desktop browser (optional)

**Dependencies:** Task 25

**Files likely touched:**
- `lib/..._web/live/overlay_live.html.heex`
- `assets/css/app.css`

**Estimated scope:** S

## Task 27: Add overlay queue tests

**Description:** Lock down queue ordering, recovery, dismissal, and alerted marking.

**Acceptance criteria:**
- [x] Queue ordering is tested.
- [x] Recovery seed is tested.
- [x] Auto-dismiss progression is tested.
- [x] Alert acknowledgement is tested.

**Verification:**
- [x] Run `mix test test/.../overlay_live_test.exs`

**Dependencies:** Task 25

**Files likely touched:**
- `test/.../overlay_live_test.exs`

**Estimated scope:** S

### Checkpoint: Overlay

- [x] Paid donations appear in the overlay
- [x] Alerts never overlap
- [x] Restart recovery replays missed alerts

## Phase 7: Admin Replay

## Task 28: Add basic auth protection for admin

**Description:** Protect the admin area with simple credentials from environment config.

**Acceptance criteria:**
- [x] `/admin` requires basic auth.
- [x] Invalid credentials are rejected.
- [x] Valid credentials allow access.

**Verification:**
- [x] Run controller, plug, or feature tests
- [x] Manual check in browser (optional)

**Dependencies:** Task 3, Task 4

**Files likely touched:**
- `lib/..._web/router.ex`
- `lib/..._web/plugs/...`
- `test/...`

**Estimated scope:** S

## Task 29: Build the admin donations list

**Description:** Show the streamer a simple functional view of all donations, statuses, and alert state.

**Acceptance criteria:**
- [x] Donations are listed in a stable order.
- [x] Status and alerted state are visible.
- [x] The page is usable without extra admin tooling.

**Verification:**
- [x] Run feature tests or manual check with seed data

**Dependencies:** Task 7, Task 28

**Files likely touched:**
- `lib/..._web/live/admin_live.ex`
- `lib/..._web/live/admin_live.html.heex`
- `test/.../admin_live_test.exs`

**Estimated scope:** S

## Task 30: Implement admin replay rebroadcast

**Description:** Add a per-donation replay action that sends the donation back through the overlay without resetting historical donation state.

**Acceptance criteria:**
- [x] Replay sends an overlay event for the selected donation.
- [x] Replay does not mutate `alerted` back to false.
- [x] Replayed alerts show again in the overlay.

**Verification:**
- [x] Run admin replay tests
- [x] Manual check with overlay open (optional)

**Dependencies:** Task 24, Task 29

**Files likely touched:**
- `lib/..._web/live/admin_live.ex`
- `test/.../admin_live_test.exs`

**Estimated scope:** M

## Task 31: Add admin tests

**Description:** Cover auth and replay so the control surface is stable.

**Acceptance criteria:**
- [x] Admin auth behavior is covered.
- [x] Replay action behavior is covered.

**Verification:**
- [x] Run feature tests for admin auth and replay

**Dependencies:** Task 30

**Files likely touched:**
- `test/.../admin_live_test.exs`

**Estimated scope:** S

## Phase 8: Operations and Polish

## Task 32: Add logging around donation lifecycle events

**Description:** Log QR creation, webhook acceptance/rejection, duplicate deliveries, and replay events without leaking secrets.

**Acceptance criteria:**
- [x] Success and failure states are visible in logs.
- [x] Secrets are not logged.
- [x] Duplicate webhook deliveries are distinguishable.

**Verification:**
- [x] Manual check of logs during local flow tests

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
