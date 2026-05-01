# PRD: Livestream Donation System

## Problem Statement

During YouTube livestreams, viewers have no direct, low-friction way to send money with a personal message that appears on stream in real time. Existing solutions (Super Chat, Trakteer, Saweria) are either platform-locked, take high cuts, or require viewers to create accounts. A personal, self-hosted system built on Indonesian payment infrastructure gives full control over the experience, the data, and the fees.

## Solution

A self-hosted Phoenix/LiveView web application with two surfaces:

1. **Donor page** — a permanent public URL where viewers fill in their name, amount, and optional message, then pay via dynamically generated QRIS (one per transaction, created via Mayar API).
2. **OBS overlay** — a separate LiveView route added as a browser source in OBS that displays real-time donation alerts (name, amount, message) as donations are confirmed via Mayar webhook.

All donations are persisted to SQLite. The host can replay missed alerts from a simple admin page.

---

## User Stories

**Viewer (donor)**

1. As a viewer, I want to open a donation URL shown on stream so I can send money without creating an account.
2. As a viewer, I want to choose from preset amounts (Rp 5.000, Rp 10.000, Rp 25.000) so I can donate quickly without thinking.
3. As a viewer, I want to enter a custom amount so I can donate exactly what I want.
4. As a viewer, I want to enter my name so the streamer knows who I am.
5. As a viewer, I want to leave an optional message so I can say something on stream.
6. As a viewer, I want a unique QRIS code generated for my transaction so I can pay with any QRIS-compatible banking app.
7. As a viewer, I want to see a confirmation after payment so I know my donation went through.
8. As a viewer, I want the flow to work on mobile so I can donate from my phone while watching.

**Streamer (host)**

9. As a streamer, I want donation alerts to appear on my OBS stream automatically after payment confirmation so I don't have to do anything manually.
10. As a streamer, I want each alert to show the donor's name, amount, and message so my audience sees the full context.
11. As a streamer, I want alerts to be queued so they display one at a time and never overlap.
12. As a streamer, I want each alert to auto-dismiss after 5 seconds so the overlay doesn't clutter the stream.
13. As a streamer, I want the alert UI to be minimal so it doesn't distract from stream content.
14. As a streamer, I want all donations saved to a database so I can review them after a stream.
15. As a streamer, I want to replay a missed alert from the admin page so donations that arrived during a crash or redeploy aren't silently lost.
16. As a streamer, I want only valid Mayar webhook requests to trigger alerts so no one can fake a donation by hitting the webhook URL directly.

**System / error states**

17. As the system, when Mayar fires a webhook, I want to write to the DB before broadcasting the alert so no donation is lost even if the LiveView broadcast fails.
18. As the system, when two donations arrive simultaneously, I want to queue both alerts so they display sequentially, not on top of each other.
19. As the system, when Mayar retries a webhook for a previously processed payment, I want to deduplicate by Mayar transaction ID so the same donation doesn't trigger two alerts.
20. As the system, when the server restarts during a stream, I want the pending alert queue to be recoverable from the DB so in-flight alerts aren't lost.

---

## Implementation Decisions

### Modules

**1. Mayar Webhook Handler**
- Responsibility: receive POST from Mayar, verify signature, parse payload, persist donation, broadcast to overlay
- Interface: accepts raw request body + signature header; returns 200 on success, 400/401 on invalid; emits internal event for overlay
- New module

**2. Donation Store**
- Responsibility: persist and retrieve donations from SQLite via Ecto
- Schema: `donations` table with fields — `id`, `mayar_transaction_id` (unique), `donor_name`, `amount` (integer, IDR), `message` (nullable), `status` (pending | paid), `alerted` (boolean), `inserted_at`
- New module; `mayar_transaction_id` unique index for deduplication

**3. Donor Page (LiveView)**
- Responsibility: render donation form, call Mayar API to create transaction, return dynamic QRIS, show confirmation
- Interface: public route `/donate`; form inputs — name (required), amount (required, preset or custom), message (optional); on submit creates Mayar transaction and renders QRIS image
- New LiveView

**4. OBS Overlay (LiveView)**
- Responsibility: listen for donation events via PubSub, maintain alert queue in socket state, render and animate alerts one at a time
- Interface: route `/overlay` (no auth, but obscure enough — a UUID path segment is sufficient); auto-dismisses each alert after 5s; pulls unalerted donations from DB on mount to recover missed alerts after restart
- New LiveView

**5. Alert Queue**
- Responsibility: ensure alerts are displayed sequentially, never overlapping
- Lives inside the Overlay LiveView process state; on each alert display, marks the donation `alerted: true` in DB; on dismiss, pops next from queue
- Not a separate module — implemented as socket assigns + `Process.send_after`

**6. Admin / Replay Page (LiveView)**
- Responsibility: list all donations, allow manual re-trigger of alert for any donation
- Interface: route `/admin` (basic auth protected); table of donations with status; "Replay Alert" button per row
- New LiveView; minimal, functional only

**7. Mayar API Client**
- Responsibility: create a Mayar transaction (returns QRIS payload), abstract HTTP details
- Interface: `create_transaction(name, amount_idr, message)` → `{:ok, %{qris_url, transaction_id}}` or `{:error, reason}`
- New module using `Req`

### Architectural decisions

- **Phoenix PubSub** for webhook → overlay communication. No external message broker needed for a single-node personal tool.
- **SQLite via Ecto** with `exqlite` adapter. No Postgres overhead for a personal single-user tool.
- **Mayar signature verification** on every webhook request before any processing. Reject and log anything that fails.
- **Deduplication** by `mayar_transaction_id` unique constraint — idempotent webhook handling, no double alerts on Mayar retries.
- **Queue in LiveView state + DB flag** — on OBS overlay mount, load all donations where `alerted: false` and `status: paid` to recover from restarts.
- **Cloudflare Tunnel or reverse proxy on VPS** to expose the app on a stable public URL for Mayar webhooks.

### Key flows

**Donation flow:**
Viewer submits form → Donor LiveView calls Mayar API → Mayar returns QRIS → Viewer scans and pays → Mayar fires webhook → Handler verifies signature → Persists donation (status: paid) → Broadcasts via PubSub → Overlay LiveView receives event → Queues alert → Displays sequentially

**Restart recovery flow:**
Overlay LiveView mounts → Queries DB for `status: paid AND alerted: false` → Loads into queue → Plays through missed alerts

---

## Testing Decisions

- **Webhook handler**: unit test signature verification (valid, invalid, missing), deduplication (same transaction ID twice), and DB write before broadcast. Mock Mayar signature generation.
- **Donation Store**: test insert, retrieval, and unique constraint on `mayar_transaction_id`.
- **Alert queue logic**: test queue ordering, sequential dispatch, and `alerted` flag update.
- **Mayar API Client**: test with mock HTTP responses (success, Mayar error, network failure).
- No end-to-end browser tests for MVP — the surface is small enough that manual testing during development is sufficient.
- Follow existing project TDD conventions (red/green, no unnecessary third-party test libraries).

---

## Out of Scope

- Per-stream tracking / stream sessions
- Viewer accounts or login
- Multiple payment methods beyond QRIS
- Sound effects on alerts
- Custom alert themes or animations beyond minimal CSS
- Analytics dashboard
- Mobile app
- Multi-streamer support
- Tipping goals / progress bars
- Integration with YouTube Live API (chat, etc.)

---

## Further Notes

- Schedule VPS deploys outside stream hours — downtime during a live stream means missed webhooks until Mayar retries.
- Mayar webhook retry behavior should be verified in their docs — confirm retry count and interval before relying on it as the failure recovery mechanism.
- The `/overlay` route should use a non-guessable path (e.g. `/overlay/:secret_token`) to prevent anyone who finds the URL from injecting fake alerts via a crafted HTML page — though the real protection is webhook signature verification.
- Start with a hardcoded `SECRET_TOKEN` for overlay path and basic auth for admin — do not over-engineer auth for a personal tool.
