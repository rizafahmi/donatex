# ADR-020: Use Basic Auth For Admin Access In MVP

## Status

Accepted

## Date

2026-05-03

## Context

Donatex is a single-streamer system with a small administrative surface:

- view donations
- manually replay alerts

The MVP does not require multi-user accounts, role management, password resets, or audit trails. It needs a simple gate to keep `/admin` private while remaining low-ops and self-host friendly.

## Decision

Protect admin LiveViews (`/admin`, `/admin/questions`) with HTTP Basic Authentication:

- credentials are provided via `ADMIN_USERNAME` and `ADMIN_PASSWORD` runtime config
- the router applies a dedicated `:admin` pipeline via `DonatexWeb.Plugs.AdminBasicAuth` (`Plug.BasicAuth`), which stamps `admin_authenticated` into the session on success
- admin live routes are wrapped in `live_session :admin` with `DonatexWeb.LiveAdminAuth` `on_mount`, because LiveView websocket mount/reconnect bypasses the plug pipeline

## Alternatives Considered

### Full authentication system (accounts + sessions)

- Pros: stronger UX and extensibility (users, roles, password reset)
- Cons: significant scope increase and additional security surface area for an MVP
- Rejected because Donatex is explicitly single-user and does not need accounts for the MVP

### Tokenized admin URL (secret path segment)

- Pros: avoids credential prompts
- Cons: weaker operational safety (URLs are easy to leak via browser history, screenshots, logs); no credential rotation without changing the URL
- Rejected because credentials are simpler to rotate and reason about

## Consequences

- Admin access is straightforward to configure and self-host.
- Production must use HTTPS to protect credentials in transit.
- Operators must treat `ADMIN_PASSWORD` as a secret and rotate it if compromised.
