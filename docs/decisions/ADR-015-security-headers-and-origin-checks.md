# ADR-015: Add CSP Security Headers And Production Origin Checks

## Status

Accepted

## Date

2026-05-02

## Context

Notable is a web app that is expected to be internet-exposed in production.

The MVP has three public surfaces:

- public donor LiveView
- overlay LiveView (unauthenticated)
- private admin LiveView behind basic auth

Even with simple access control, browser-level protections should reduce risk from:

- clickjacking and unwanted embedding
- unsafe resource loading and script injection
- overly-permissive cross-origin websocket connections in production

The donor and overlay pages also load external images (Mayar QR image URLs), and LiveView requires websocket connectivity.

## Decision

1. Apply a shared set of browser security headers to both `:browser` and `:api` pipelines.
2. Use a strict Content Security Policy (CSP) that:
   - allows LiveView websocket connections
   - allows remote QR images while keeping other sources locked down
   - avoids `unsafe-inline` scripts by allowing the one required inline bootstrap script via a CSP script hash
3. Enable origin checking in production by deriving `check_origin` from `NOTABLE_BASE_URL` (temporary alias: `DONATEX_BASE_URL`).
4. Include `x-content-type-options: nosniff` in the shared headers.

## Alternatives Considered

### Keep Phoenix defaults only

- Pros: no additional configuration
- Cons: misses protections needed for an internet-exposed deployment (especially CSP and frame restrictions)
- Rejected to keep production posture aligned with the MVP security constraints

### Use CSP nonces everywhere

- Pros: very flexible, allows inline scripts without hashes
- Cons: requires nonce injection into the root layout; more moving parts than needed for a small app
- Rejected because Notable currently only needs one stable inline bootstrap script

### Disable origin checking in production

- Pros: fewer connection issues under misconfiguration
- Cons: enables cross-site websocket attempts against the LiveView endpoint
- Rejected because origin checks are low-cost hardening and are compatible with env-driven runtime config

## Consequences

- The application gains a stable baseline security header policy that applies to all routes.
- LiveView continues to work without enabling `unsafe-inline` for scripts.
- Production deployments must set `NOTABLE_BASE_URL` correctly (or the temporary `DONATEX_BASE_URL` alias) so origin checks accept the correct scheme/host/port.
