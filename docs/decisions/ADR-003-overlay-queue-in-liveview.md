# ADR-003: Keep Alert Queue In Overlay LiveView State

## Status

Accepted

## Context

The overlay must show one alert at a time, auto-dismiss after 5 seconds, and recover missed alerts after restart. The product is single-streamer and single-overlay, and the database already stores enough information to reconstruct missed alerts.

## Decision

Keep the runtime alert queue inside `NotableWeb.OverlayLive` state and reconstruct missed alerts from the database on mount.

## Alternatives Considered

### Dedicated GenServer queue

- Pros: central runtime queue process
- Cons: more moving parts, extra coordination, still needs DB for durable recovery
- Rejected because it adds complexity without increasing correctness for MVP

### External queue or broker

- Pros: durable distributed queue semantics
- Cons: operational overhead, completely disproportionate to the product scope
- Rejected because the app is intentionally a small single-node MVP

## Consequences

- Overlay logic stays close to the UI it serves
- Durable replay semantics still come from the database
- The architecture remains simple and easy for agents to reason about
- If multiple overlays or distributed consumers are introduced later, a new ADR will be needed
