# ADR-011: Use Secure HttpOnly Session Cookies In Production

## Status

Accepted

## Date

2026-05-02

## Context

Notable uses cookie-backed sessions for Phoenix features such as LiveView connect info and flash messages.

For production deployments, session cookies must be protected against:

- JavaScript access (XSS impact reduction)
- being sent over plain HTTP

Local development typically runs over HTTP, so production-hardening must not break the default dev workflow.

## Decision

- Always set session cookies as HttpOnly.
- Set the session cookie `Secure` flag in production builds only, using a compile-time app config flag.

Implemented in `NotableWeb.Endpoint` via:

- `http_only: true`
- `secure: Application.compile_env(:notable, :secure_cookies, false)`

and enabled in production via `config :notable, :secure_cookies, true`.

## Alternatives Considered

### Always set `secure: true`

- Pros: simplest and safest default
- Cons: breaks local development over HTTP unless developers also configure HTTPS locally
- Rejected to keep the default local workflow simple

### Leave the session cookie flags at Phoenix defaults

- Pros: no changes required
- Cons: weaker cookie protection in production than needed for an internet-exposed app
- Rejected because strengthening cookie defaults is low-risk and aligned with MVP security constraints

## Consequences

- Production sessions are not readable by JavaScript and are only sent over HTTPS.
- Local development stays unchanged (HTTP works without additional setup).
