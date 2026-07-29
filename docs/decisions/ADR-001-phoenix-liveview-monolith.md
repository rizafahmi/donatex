# ADR-001: Use A Phoenix LiveView Monolith

## Status

Accepted

## Context

Notable is a single-streamer donation tool with a very small product surface: one donor page, one overlay page, one admin page, one payment provider, and one local database. The system needs real-time updates, durable persistence, and simple operations.

## Decision

Implement Notable as a single Phoenix LiveView application backed by SQLite and Phoenix PubSub.

## Alternatives Considered

### Split frontend and backend services

- Pros: hard separation of concerns, independent deployment units
- Cons: unnecessary complexity, duplicated state contracts, more moving parts for a solo-operated system
- Rejected because the product surface is too small to justify the operational overhead

### API-only backend with separate JavaScript frontend

- Pros: frontend framework flexibility
- Cons: more client/server contract work, more state synchronization, less leverage from LiveView for real-time updates
- Rejected because LiveView already fits the required donor, overlay, and admin surfaces well

## Consequences

- Faster implementation with one stack
- Simpler PubSub integration for overlay updates
- Lower operational complexity for MVP
- If scale or team shape changes later, this decision may be revisited with a new ADR
