# ADR-019: Deploy On A Single VM Using Mix Releases And systemd

## Status

Accepted

## Date

2026-05-02

## Context

Notable is a single-streamer Phoenix LiveView application with a SQLite database file. It must remain simple to operate and cheap to host.

For the MVP, we want:

- a deployment strategy that works on a single Linux VM
- no Docker requirement
- a simple, fast deploy/rollback flow
- a process supervisor so the app restarts after VM reboots
- HTTPS support for Mayar webhooks and LiveView sessions

The chosen approach is guided by:

- `https://damonvjanis.medium.com/optimizing-for-free-hosting-elixir-deployments-6bfc119a1f44`

## Decision

Deploy Notable to a single VM (for example, a GCP free-tier instance) using:

- `mix release` for build artifacts
- `systemd` to supervise the release and restart it after reboots
- a simple “current symlink” or equivalent directory layout to support fast rollbacks
- SQLite persisted as a file at `DATABASE_PATH` on the VM’s persistent disk

Operational guidance lives in `docs/OPERATIONS.md`.

## Alternatives Considered

### Platform-as-a-service (Fly, Render, Gigalixir, etc.)

- Pros: minimal ops, managed TLS, easy deploy UX
- Cons: higher cost floor, harder to control filesystem semantics for SQLite, more vendor constraints
- Rejected for MVP: goal is “cheap and simple on a single box”

### Docker-based deployment

- Pros: portable builds, reproducible environments
- Cons: adds complexity and operational overhead for the MVP, not required for a single VM
- Rejected for MVP: prefer fewer moving parts

### Use Postgres instead of SQLite

- Pros: easier multi-node scaling later, well understood remote backups
- Cons: violates the MVP constraint that SQLite is the system of record
- Rejected: out of scope for MVP

## Consequences

- The VM filesystem (persistent disk) is part of the reliability story; the SQLite database file must be backed up.
- Deploy tooling is intentionally minimal; the team must maintain a small set of release scripts and systemd units.
- Scaling beyond a single node is possible but not a goal for MVP; it likely requires moving away from SQLite or carefully managing write contention.
