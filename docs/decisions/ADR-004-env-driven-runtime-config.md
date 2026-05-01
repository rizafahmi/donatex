# ADR-004: Use Env-Driven Runtime Configuration And A Local `.env` Workflow

## Status

Accepted

## Context

Donatex needs runtime configuration for:

- Mayar API base URL and API key
- An overlay route token used to gate OBS access
- Basic auth credentials for the admin page
- The public base URL of the application

These values are secrets or deployment-specific, so they must not be committed to the repository. The app also targets a simple solo-streamer deployment, so the local development workflow should be straightforward and not require additional tooling.

## Decision

- Store all secrets and deployment-specific configuration in environment variables.
- In production, fail fast on boot if any required env var is missing.
- In development, document a `source .env` workflow and provide a committed `.env.example` template.
- Provide a small `Donatex.Config` module as the single internal access point for these values.

## Alternatives Considered

### Commit local secrets in repository config files

- Pros: simplest setup, no extra steps for developers
- Cons: high risk of credential leakage and accidental distribution of secrets
- Rejected because secrets must never be committed

### Use a dedicated config library (dotenv loaders, vault clients)

- Pros: potentially better ergonomics, can support more complex secret sources
- Cons: more dependencies and operational surface area than needed for MVP
- Rejected because the MVP can meet requirements with environment variables and documentation

## Consequences

- Production misconfiguration fails early and clearly, rather than failing later during donation handling.
- Local development requires one explicit step (`source .env`) but avoids committing secrets.
- A single config module (`Donatex.Config`) makes future refactors (e.g., moving to releases, secret managers) localized and testable.

