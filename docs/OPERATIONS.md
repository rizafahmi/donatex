# Operations (Setup & Deployment)

## Overview

Donatex is a single-streamer Phoenix LiveView app with three surfaces:

- Donor page: `/donate`
- OBS overlay: `/overlay/:token`
- Admin page: `/admin`

Payments are created as Mayar dynamic QRIS transactions. Donatex creates a local `pending` donation row when the QR is generated, then upgrades it to `paid` when Mayar sends a webhook. The overlay shows paid donations as sequential alerts and recovers missed alerts after restarts by querying `paid AND alerted = false` from SQLite.

## Environment Variables

These values are expected to be provided via environment variables. In development, the intended workflow is `source .env` before starting the server. In production, set these variables in your process manager / container environment (do not rely on `.env` files).

### Application URLs

- `DONATEX_BASE_URL`
  - Public base URL used to build links and derive LiveView origin checks.
  - Example: `https://donate.example.com`
- `PHX_HOST`
  - Public host used for Phoenix endpoint URL config.
  - Example: `donate.example.com`

### Database (Production)

- `DATABASE_PATH`
  - Absolute SQLite path used in production.
  - Example: `/etc/donatex/donatex.db`
- `POOL_SIZE` (optional)
  - Defaults to `5`.

### Phoenix Runtime

- `SECRET_KEY_BASE`
  - Required in production.
  - Generate with: `mix phx.gen.secret`
- `PORT` (optional)
  - Defaults to `4000`.
- `PHX_SERVER`
  - Set to `true` when running as a server in a release / production environment.
- `DNS_CLUSTER_QUERY` (optional)
  - Only needed when using Phoenix DNS clustering.

### Mayar Integration

- `MAYAR_API_BASE_URL`
  - Sandbox: `https://api.mayar.club/hl/v1`
  - Production: `https://api.mayar.id/hl/v1`
- `MAYAR_API_KEY`
- `MAYAR_WEBHOOK_TOKEN`
  - Non-guessable token embedded in the registered Mayar webhook callback URL.
  - Production enforces a minimum length (20+ characters).

### Overlay & Admin

- `OVERLAY_TOKEN`
  - Non-guessable token used by `/overlay/:token`.
  - Production enforces a minimum length (20+ characters).
- `ADMIN_USERNAME`
- `ADMIN_PASSWORD`

## Public URLs (What To Copy Into OBS / Mayar)

Assuming `DONATEX_BASE_URL=https://donate.example.com`:

- Donor page: `https://donate.example.com/donate`
- Overlay (OBS Browser Source): `https://donate.example.com/overlay/<OVERLAY_TOKEN>`
- Admin: `https://donate.example.com/admin`
- Mayar webhook callback URL: `https://donate.example.com/webhooks/mayar/<MAYAR_WEBHOOK_TOKEN>`

## Mayar Webhook Setup

Mayar webhook authenticity is currently treated as a URL-secret model (token in the callback path). Mayar’s public docs do not describe a signature/HMAC mechanism.

1. Choose a long random `MAYAR_WEBHOOK_TOKEN`.
2. Register the webhook callback URL containing that token:
   - `https://<your-host>/webhooks/mayar/<MAYAR_WEBHOOK_TOKEN>`
3. Ensure the webhook is configured to deliver `payment.received` events.
4. If Mayar’s webhook UI provides a “test webhook” feature, use it against the same callback URL.

## Recovery & Retry Semantics

### Webhook retries and duplicates

- Webhook delivery is expected to be at-least-once; duplicates are handled idempotently by `mayar_transaction_id`.
- Donatex updates the DB before broadcasting `donations:paid`. A duplicate webhook delivery should not rebroadcast.
- If a webhook arrives for a `mayar_transaction_id` that does not exist locally, Donatex logs a warning and does not create a donation row.

### Overlay recovery

- The overlay LiveView loads missed alerts on mount by querying `paid AND alerted = false` donations.
- Alerts are displayed sequentially and auto-dismiss after 5 seconds.
- Each displayed alert is marked `alerted=true` in SQLite.

### Admin replay

- Admin replay rebroadcasts an overlay event for a selected donation.
- Replay does not mutate `alerted` back to `false`.

## Production Notes

- Terminate TLS in front of the app (Mayar webhooks should use HTTPS).
- Keep `/overlay/:token` and `/webhooks/mayar/:token` URLs private; treat the tokens as secrets.
- If you change `DONATEX_BASE_URL`, ensure it matches the URL users actually load in browsers (LiveView origin checks use it).

## GCP Free Tier Deployment (Single VM)

This project can be deployed following the “single server, no Docker” approach in:

- `https://damonvjanis.medium.com/optimizing-for-free-hosting-elixir-deployments-6bfc119a1f44`

Donatex differs from the article’s example in one major way: Donatex uses SQLite (a local file) instead of Postgres. On GCP, use a persistent disk (the default boot disk is already persistent) and set `DATABASE_PATH` to an absolute path on that disk.

### High-level Checklist

1. Provision a free-tier VM (Ubuntu) and point your domain DNS at the VM’s static IP.
2. Install Erlang/Elixir for the versions used by this repo.
3. Ensure HTTPS termination exists (Caddy, nginx, or a managed load balancer).
4. Forward ports 80/443 to the Phoenix port (or run Phoenix on 443 directly).
5. Create a deploy user + configure SSH access.
6. Put secrets/env vars on the VM (systemd drop-in, env file readable only by root, or equivalent).
7. Build and run a release, then manage it via systemd.
8. Back up the SQLite database file (`DATABASE_PATH`) regularly.

### Release Commands

From the app directory on the VM:

- Build assets: `MIX_ENV=prod mix assets.deploy`
- Build release: `MIX_ENV=prod mix release`
- Run migrations: `_build/prod/rel/donatex/bin/migrate`
- Start server: `_build/prod/rel/donatex/bin/server`

### systemd (Example)

If you follow the article’s “release directory + current symlink” layout (e.g. `/opt/donatex/current`), a minimal systemd unit can run the release `server` script:

```
[Unit]
Description=donatex
After=network.target

[Service]
Type=simple
User=donatex
WorkingDirectory=/opt/donatex/current
EnvironmentFile=/etc/donatex/donatex.env
ExecStart=/opt/donatex/current/bin/server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### SQLite Notes

- Keep the database file outside the release directory so deploys don’t overwrite it.
- Use an absolute path like `/etc/donatex/donatex.db` and ensure the directory exists and is writable by the app user.
