# ADR-022: Remove Overlay Token Route

## Status

Accepted

## Date

2026-05-03

## Context

Notable is a single-user livestream donation system. The OBS overlay is loaded by the streamer inside OBS as a browser source.

The project previously used a non-guessable token embedded in the overlay route to keep the overlay private without introducing an accounts system (ADR-021).

For the current MVP:

- the system is deployed for a single streamer and a single overlay consumer (OBS)
- the overlay route is not treated as a security boundary
- keeping an extra overlay token and token validation logic adds configuration and documentation overhead

## Decision

Remove the token-gated overlay route and serve the overlay at a stable route:

- `GET /overlay`
- remove the overlay token runtime configuration (`OVERLAY_TOKEN`)
- remove the overlay-token plug/pipeline from the router

This supersedes ADR-021.

## Alternatives Considered

### Keep the tokenized overlay route

- Pros: keeps the overlay URL private by default
- Cons: adds configuration and operational burden without solving a current MVP need

### Protect overlay with HTTP Basic Auth

- Pros: standard, stronger than a URL secret
- Cons: worse OBS UX and extra credential handling

### Put overlay behind an external access control layer

- Pros: can be strong (reverse proxy auth, IP allowlist, VPN)
- Cons: deployment-specific and out of scope for the app itself

## Consequences

- The overlay is now reachable by anyone who can access the host at `/overlay`.
- If the overlay should not be publicly accessible, deployments should enforce access control outside the app (reverse proxy auth, IP allowlist, or a private network).
