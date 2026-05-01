# Donatex Architecture

## Purpose

This document describes the target application architecture for Donatex. It is written for LLM agents that will implement and extend the system. It should be treated as the architectural source of truth until superseded by later ADRs.

This is a target-state document, not a description of the current repository state. The current codebase is still mostly the default Phoenix skeleton.

## System Goal

Donatex is a self-hosted livestream donation app for a single streamer. It has three user-facing surfaces:

- A public donor page at `/donate`
- A private OBS overlay at `/overlay/:token`
- A private admin page at `/admin`

The system must create one Mayar QRIS payment per donation, persist donation state in SQLite, update donation state from webhook events, and show paid donations as sequential overlay alerts that can be replayed from the admin page.

## Hard Constraints

- Single-user, single-streamer system only
- Phoenix 1.8 + LiveView application
- SQLite is the system of record
- `Req` is the HTTP client for Mayar integration
- Donor flow must work on mobile
- Overlay alerts only appear after payment confirmation
- Alerts must never overlap
- Alerts auto-dismiss after 5 seconds
- Overlay recovery must replay `paid` donations where `alerted = false`
- Webhook handling must persist before broadcast
- Duplicate webhooks must be deduplicated by `mayar_transaction_id`
- Admin auth is basic auth for MVP
- Overlay access uses a non-guessable token in the route
- Do not introduce multi-stream, analytics, accounts, extra payment methods, or a separate queue service

## Architecture Summary

- Phoenix LiveView handles all user-facing surfaces
- Ecto + SQLite persist all donation state
- Phoenix PubSub carries internal donation-alert events
- The overlay queue lives inside the overlay LiveView process state
- The database, not process memory, is the durable source of truth
- The donor page creates local `pending` donations before Mayar payment confirmation
- Mayar webhook processing upgrades matching donations to `paid`, then broadcasts alert events
- Overlay recovery reads missed paid-but-unalerted rows from SQLite at mount time

## High-Level Topology

```diagram
╭────────────────╮
│ Donor Browser  │
╰──────┬─────────╯
       │ LiveView form submit
       ▼
╭─────────────────────────────╮
│ DonatexWeb.DonateLive       │
│ creates pending donation    │
│ requests QR from Mayar      │
╰───────────┬─────────────────╯
            │ Req
            ▼
      ╭──────────────╮
      │ Mayar API    │
      ╰──────┬───────╯
             │ webhook POST
             ▼
╭─────────────────────────────╮
│ Mayar Webhook Controller    │
│ + webhook handler           │
╰───────────┬─────────────────╯
            │ persist then broadcast
            ▼
╭─────────────────────────────╮
│ SQLite / Donations context  │
╰───────────┬─────────────────╯
            │ PubSub
            ▼
╭─────────────────────────────╮
│ DonatexWeb.OverlayLive      │
│ in-memory alert queue       │
╰───────────┬─────────────────╯
            │ replay action
            ▼
╭─────────────────────────────╮
│ DonatexWeb.AdminLive        │
╰─────────────────────────────╯
```

## Core Design Principles

### Database First

SQLite is the durable source of truth. The overlay queue is transient runtime state only. Any runtime state that matters after restart must be derivable from persisted donation rows.

### Functional Context Boundary

Business operations should sit in explicit context or integration modules, not inside controllers or LiveViews. LiveViews orchestrate UI state and call application boundaries.

### Small Monolith

This app should remain a single Phoenix application. Do not split into services, workers, or brokers without clear evidence that the simple architecture is insufficient.

### Queue In LiveView, Not In A Dedicated Service

The alert queue is an implementation detail of the overlay client. For MVP, it should live in `DonatexWeb.OverlayLive` assigns plus timers. Do not add a separate GenServer queue service unless the current approach proves inadequate.

## Proposed Module Map

The current repo does not implement these modules yet. This is the intended target structure.

### Domain And Persistence

- `Donatex.Donations`
  - Application boundary for donation lifecycle
  - Creates pending donations
  - Marks donations paid
  - Marks donations alerted
  - Lists donations for admin
  - Fetches paid/unalerted donations for overlay recovery

- `Donatex.Donations.Donation`
  - Ecto schema and changeset
  - Owns validation for fields and status values

### Mayar Integration

- `Donatex.Mayar.Client`
  - Wraps `Req`
  - Creates dynamic QRIS transactions
  - Normalizes Mayar success/error responses

- `Donatex.Mayar.Webhook`
  - Parses webhook payloads
  - Extracts `event`, transaction identifiers, amount, donor fields, and status fields

- `Donatex.Mayar.WebhookAuth`
  - Encapsulates whatever authenticity mechanism is confirmed
  - Must remain isolated because the Mayar docs do not clearly document signature verification

- `Donatex.Mayar.WebhookHandler`
  - Processes accepted webhook payloads
  - Updates DB first
  - Broadcasts PubSub event second
  - Enforces idempotent handling

### Web Layer

- `DonatexWeb.DonateLive`
  - Public donation page
  - Form entry, preset/custom amounts, QR rendering, waiting state, paid state

- `DonatexWeb.OverlayLive`
  - Private overlay UI
  - Subscribes to donation alert events
  - Seeds queue from DB on mount
  - Displays one alert at a time
  - Marks alerts as acknowledged in the DB

- `DonatexWeb.AdminLive`
  - Basic-auth protected admin page
  - Lists donations and replay action

- `DonatexWeb.MayarWebhookController`
  - Receives webhook requests
  - Hands off to auth/parser/handler modules
  - Avoids embedding business logic

- `DonatexWeb.Plugs.AdminBasicAuth`
  - Basic auth gate for admin routes

## Data Model

The core persisted entity is `Donation`.

### Donations Table

Implemented fields:

- `id` - local primary key
- `mayar_transaction_id` - unique Mayar transaction identifier
- `donor_name` - required donor display name
- `amount` - integer IDR amount
- `message` - nullable donor message
- `status` - `pending | paid`
- `alerted` - boolean for overlay acknowledgement state
- `inserted_at`
- `updated_at`

### State Semantics

- `pending`
  - Local record created after donor submits the form and a QR is generated
  - Donation exists, but payment is not yet confirmed

- `paid`
  - Confirmed from Mayar webhook handling
  - Eligible for overlay broadcast and replay

- `alerted = false`
  - Paid donation has not yet completed overlay acknowledgement flow

- `alerted = true`
  - Donation has already been displayed or otherwise acknowledged by the overlay path

## Runtime Components

The current supervisor from [lib/donatex/application.ex](file:///Users/riza/code/donatex/lib/donatex/application.ex) is already a good base for the target app:

- `DonatexWeb.Telemetry`
- `Donatex.Repo`
- `Ecto.Migrator`
- `DNSCluster`
- `Phoenix.PubSub`
- `DonatexWeb.Endpoint`

No extra OTP process is required for donation queueing in the MVP architecture.

## Routing Model

The current router in [lib/donatex_web/router.ex](file:///Users/riza/code/donatex/lib/donatex_web/router.ex) should evolve toward this shape:

- Browser routes
  - `/donate`
  - `/overlay/:token`
  - `/admin`

- Webhook route
  - `POST /webhooks/mayar/:token`

Admin should sit behind a browser pipeline plus `Plug.BasicAuth` or a small custom plug. The overlay token is not authentication in the full sense; it is route secrecy for MVP access control.

## Internal Eventing

Phoenix PubSub is the internal real-time backbone.

### Suggested Event Topics

- `donations:paid`
  - Fired after a donation is marked paid in the DB

- `donations:replay`
  - Fired when admin requests a replay

The exact topic naming can be adjusted, but the event contract should stay simple: enough data for overlay rendering without re-querying on every event, while still allowing DB-backed recovery on reconnect.

## Primary Flows

### Flow 1: Donor Creates QR

```diagram
╭──────────────╮
│ Donor opens  │
│ /donate      │
╰──────┬───────╯
       ▼
╭────────────────────────────╮
│ DonatexWeb.DonateLive      │
│ validates form             │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ Donatex.Donations          │
│ create pending donation    │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ Donatex.Mayar.Client       │
│ POST /qrcode/create        │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ DonateLive renders QR      │
│ and waiting state          │
╰────────────────────────────╯
```

### Flow 2: Payment Confirmation

```diagram
╭──────────────╮
│ Mayar sends  │
│ webhook POST │
╰──────┬───────╯
       ▼
╭────────────────────────────╮
│ MayarWebhookController     │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ WebhookAuth                │
│ accept or reject request   │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ Webhook parser             │
│ extract payment fields     │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ Donations/WebhookHandler   │
│ mark donation paid         │
│ dedupe by tx id            │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ PubSub broadcast           │
╰──────┬───────────┬─────────╯
       │           │
       ▼           ▼
╭──────────────╮  ╭──────────────╮
│ OverlayLive  │  │ DonateLive   │
│ enqueue alert│  │ show paid UI │
╰──────────────╯  ╰──────────────╯
```

### Flow 3: Overlay Recovery And Replay

```diagram
╭────────────────────────────╮
│ OverlayLive mounts         │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ Donations query            │
│ status = paid              │
│ alerted = false            │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ Seed in-memory queue       │
│ display one alert          │
│ every 5 seconds            │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ Mark donation alerted      │
╰────────────────────────────╯

╭────────────────────────────╮
│ AdminLive replay click     │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ PubSub replay broadcast    │
╰──────┬─────────────────────╯
       ▼
╭────────────────────────────╮
│ OverlayLive enqueues again │
│ without resetting DB state │
╰────────────────────────────╯
```

## Overlay Queue Design

### Chosen Approach

Queue state lives in `DonatexWeb.OverlayLive` assigns.

Suggested assigns:

- `current_alert`
- `queued_alerts`
- `dismiss_timer_ref` or equivalent implicit timer behavior

Suggested behavior:

- On mount, subscribe to PubSub and fetch recovery rows
- If nothing is showing, display the next donation immediately
- If an alert is already visible, append new donations to the queue
- Use `Process.send_after/3` to dismiss after 5 seconds
- On dismissal, mark the displayed donation as alerted and move to the next one

### Explicit Non-Goal

Do not introduce:

- A dedicated GenServer alert queue
- An external broker
- A persistent in-memory queue abstraction separate from the DB and overlay LiveView

That would add system complexity without solving an MVP problem the current design cannot handle.

## Webhook Security Risk

The PRD requires that only valid Mayar webhooks trigger alerts. The published Mayar documentation reviewed for this project documents webhook payloads and management endpoints, but does not document a request signature header, shared secret exchange, or HMAC verification scheme.

For MVP, Donatex adopts a fallback trust model instead of assuming undocumented signing exists.

### Required Handling

- Isolate authenticity checks in `Donatex.Mayar.WebhookAuth`
- Register an HTTPS callback URL that includes a non-guessable `MAYAR_WEBHOOK_TOKEN`
- Reject requests whose token does not match before any database writes or PubSub broadcast
- Do not spread webhook trust assumptions through controller or business logic
- Keep payload validation and donation correlation checks even after token verification

### Residual Risk

- The URL-secret model is weaker than signed webhooks because it does not prove payload integrity
- If Mayar later documents an official signing mechanism, replace the token fallback in `Donatex.Mayar.WebhookAuth`

## Error And Idempotency Model

### Webhook Handling

- Reject malformed or unauthorized webhook requests early
- Ignore or safely no-op duplicate deliveries
- Persist before broadcasting
- Return success for already-processed duplicate events when appropriate to avoid useless retries

### Donor Flow

- Failure to create a Mayar QR should not leave the user in a fake success state
- Pending donation creation and Mayar QR creation should be coordinated carefully to avoid abandoned bad rows
- If a pending row is created before the external QR request fails, recovery or cleanup strategy should be explicit in the implementation

### Overlay Runtime

- Overlay crashes are acceptable if the supervisor restarts the LiveView process
- Lost runtime queue state is acceptable because the DB-backed recovery query reconstructs missed paid alerts

## Configuration Boundaries

Configuration should remain brief, env-driven, and boring.

Expected runtime configuration includes:

- `MAYAR_API_BASE_URL`
- `MAYAR_API_KEY`
- `OVERLAY_TOKEN`
- `ADMIN_USERNAME`
- `ADMIN_PASSWORD`
- application base URL or endpoint host values as needed

The architecture assumes `.env` is used for local development convenience, but runtime configuration should still be read through Phoenix/Elixir environment APIs.

## Testing Architecture

The testing strategy should protect behavior at the highest valuable layer without over-testing glue code.

### Must-Have Coverage

- Donations context
  - pending creation
  - paid transition
  - alert acknowledgement
  - recovery query

- Mayar client
  - success response normalization
  - failure normalization

- Webhook path
  - invalid request rejection
  - duplicate handling
  - DB write before broadcast

- Overlay behavior
  - queue ordering
  - no overlap
  - auto-dismiss
  - recovery replay

- Admin replay
  - auth protection
  - replay rebroadcast behavior

### Recommended Testing Levels

- Unit tests for parser and context behavior
- LiveView tests for donor, overlay, and admin interactions
- Controller tests for webhook acceptance/rejection
- Manual end-to-end smoke testing for the full donor-to-overlay flow

## Quality Gates For Agents

Before merging meaningful changes into this architecture, agents should confirm:

- `mix precommit` passes
- No architecture change violates hard constraints from the PRD
- New code keeps business logic out of controllers and LiveView templates
- No separate queue service was introduced without explicit justification
- No multi-stream or multi-tenant abstractions were added
- Persistence remains the source of truth for replay/recovery semantics

## Implementation Guidance For Agents

### Do

- Keep module names explicit and domain-focused
- Keep Mayar integration isolated behind a client module
- Keep webhook parsing and authenticity checks separated
- Keep overlay queue logic local to the overlay LiveView
- Prefer the smallest correct change that respects the architecture

### Do Not

- Do not design for multiple streamers
- Do not add user accounts or admin subsystems beyond basic auth
- Do not introduce background job infrastructure for the MVP donation path
- Do not move durable business state into GenServers
- Do not assume undocumented Mayar webhook security behavior is real without verification

## ADR Index

Architecture decisions live under [docs/decisions](file:///Users/riza/code/donatex/docs/decisions).

- [ADR-001: Use A Phoenix LiveView Monolith](file:///Users/riza/code/donatex/docs/decisions/ADR-001-phoenix-liveview-monolith.md)
- [ADR-002: Persist Donations At QR Creation Time](file:///Users/riza/code/donatex/docs/decisions/ADR-002-persist-pending-donations.md)
- [ADR-003: Keep Alert Queue In Overlay LiveView State](file:///Users/riza/code/donatex/docs/decisions/ADR-003-overlay-queue-in-liveview.md)
- [ADR-004: Env-Driven Runtime Config](file:///Users/riza/code/donatex/docs/decisions/ADR-004-env-driven-runtime-config.md)
- [ADR-005: Land Placeholder Routes Early](file:///Users/riza/code/donatex/docs/decisions/ADR-005-placeholder-public-surfaces.md)
- [ADR-006: Donations Table Schema](file:///Users/riza/code/donatex/docs/decisions/ADR-006-donations-table-schema.md)

Future ADRs should cover:

- Final webhook authenticity mechanism
- Final Mayar transaction-to-local donation correlation strategy
- Any future deployment or backup strategy if the system grows beyond MVP
