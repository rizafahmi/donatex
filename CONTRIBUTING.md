## Contributing

Thanks for considering a contribution to Donatex.

## Ground rules
- This is intentionally a single-streamer, single-instance app (not multi-tenant).
- Keep the MVP scope tight (no accounts, no analytics dashboard, no extra payment methods beyond QRIS).
- Prefer small changes with tests.

If you’re proposing an architectural change, read [ARCHITECTURE.md](docs/ARCHITECTURE.md) and the ADRs in [docs/decisions](docs/decisions) first.

## Development setup
Prereqs:
- Elixir 1.18+
- SQLite 3

Setup:
- `mix setup`
- `cp .env.example .env`
- Set at least `MAYAR_API_KEY` in `.env`
- `source .env`
- `mix phx.server`

Local surfaces:
- `http://localhost:4000/donate`
- `http://localhost:4000/overlay`
- `http://localhost:4000/admin`

## Running tests
- `mix test`
- Full verification: `mix precommit`

## Submitting a PR
1. Create a focused branch.
2. Keep PRs small and scoped to one change.
3. Add/adjust tests for behavior changes.
4. Run `mix test` (or `mix precommit`).
5. In the PR description, include:
   - what changed
   - why
   - how to verify

## Reporting bugs
Please include:
- steps to reproduce
- expected vs actual behavior
- logs (redact secrets like `MAYAR_API_KEY` and webhook URLs containing `MAYAR_WEBHOOK_TOKEN`)
- your environment (Elixir, OTP, OS)
