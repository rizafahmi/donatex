# Plan Context: Livestream Donation System

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
