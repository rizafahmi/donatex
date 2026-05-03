# ADR-021: Use A Non-Guessable Token Route For Overlay Access

## Status

Superseded by ADR-022

## Date

2026-05-03

## Context

The OBS overlay is served from a regular web route (`/overlay/:token`) and is meant to be loaded inside OBS as a browser source.

For the MVP:

- there is no viewer login system
- the overlay still must not be publicly accessible to random users
- the streamer needs a simple “copy this URL into OBS” workflow

## Decision

Use a non-guessable token embedded in the overlay route as the MVP access control:

- `OVERLAY_TOKEN` is provided via runtime config
- the router applies an `:overlay` pipeline that validates `:token` using constant-time compare
- invalid tokens return `404 Not Found`

## Alternatives Considered

### HTTP Basic Auth for overlay

- Pros: easy, uses a standard browser auth prompt
- Cons: OBS UX is worse; credentials handling is more brittle across OBS/browser-source setups
- Rejected to keep the OBS setup as “paste URL and go”

### Full authentication system

- Pros: strongest access control model
- Cons: large scope increase and explicitly out of MVP
- Rejected

### IP allowlist / network restrictions

- Pros: strong if feasible
- Cons: not portable for streamers and does not work well with dynamic home IPs or remote streaming setups
- Rejected

## Consequences

- The overlay URL must be treated as a secret (like a password).
- Deployments should avoid logging full overlay URLs to reduce token leakage.
- This is access-by-secrecy, not user authentication; if leaked, rotate `OVERLAY_TOKEN`.
