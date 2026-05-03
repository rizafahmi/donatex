# ADR-005: Land Placeholder Routes Early

## Status

Accepted

## Date

2026-05-01

## Context

The MVP has exactly two primary public surfaces (donor page and OBS overlay), plus a simple admin page and a Mayar webhook endpoint. Many later tasks depend on stable route shapes and mounting points (LiveView vs controller) so the work can proceed in small vertical slices.

Without these routes existing early, later implementation tasks tend to mix routing concerns with feature logic, increasing diff size and making tests harder to scope.

## Decision

Create placeholder implementations for:

- `GET /donate` (LiveView)
- `GET /overlay` (LiveView)
- `GET /admin` (LiveView)
- `POST /webhooks/mayar` (controller, JSON)

These placeholders should be minimal and safe:

- Render only simple headings (no feature logic).
- Do not render secrets (for example webhook callback tokens).
- Keep webhook logic as a stub until the integration contract is implemented.

## Alternatives Considered

### Implement routes only when feature logic is ready

- Pros: fewer placeholder files
- Cons: later tasks become larger and mix routing + business logic + UI
- Rejected because it increases implementation coupling and slows iteration

### Add routes but return 404/501 until implemented

- Pros: keeps code minimal
- Cons: breaks route-based tests and complicates manual QA and LiveView mounting
- Rejected because stable mounts are a dependency for TDD on later slices

## Consequences

- The app establishes its public interface early, enabling incremental delivery.
- Future changes can focus on behavior without churn in router wiring.
- Placeholder code must remain minimal to avoid “temporary” logic becoming permanent.
