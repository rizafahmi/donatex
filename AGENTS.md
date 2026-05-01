# AGENTS.md

## Project Overview

Single-user livestream donation system.
Elixir 1.18, Phoenix 1.8, SQLite 3, Tailwind 4

## Quick Start

- Install: `mix setup`
- Start:  `mix phx.server` or inside IEx REPL with `iex -S mix phx.server`
- Test: `mix test`
- Full verification: `mix precommit`

## Constraints
- The app is a single-user, single-streamer system, not multi-tenant.
- It must have exactly two primary public surfaces: donor page and OBS overlay, plus a simple admin page.
- Donations must be persisted to SQLite.
- The donor flow must use Mayar-generated dynamic QRIS, one per transaction.
- The overlay must show alerts only after payment confirmation.
- Alerts must be queued sequentially, never overlap, and auto-dismiss after 5 seconds.
- The overlay must recover missed alerts by loading paid AND alerted = false donations from storage after restart.
- Webhook handling must write to DB before broadcast.
- Duplicate webhook deliveries must be deduplicated by mayar_transaction_id.
- The admin page must allow manual replay of missed alerts.
- The donor flow must work on mobile.
- The admin auth should stay simple for MVP: basic auth, not a full auth system.
- The overlay route should use a non-guessable token/secret path.
- Out-of-scope items are hard “not now” constraints for MVP: no viewer accounts, no multi-streamer support, no analytics dashboard, no custom alert themes, no sound effects, no YouTube API integration, no tipping goals, no mobile app.
- HTTP integration should use `Req`, not `HTTPoison`, `Tesla`, or `:httpc`.
- Forms in LiveView must use `to_form/2` and the shared `<.input>` component.
LiveView pages should follow Phoenix 1.8 layout conventions, including wrapping content in `<Layouts.app ...>`.
- For collections in LiveView, the project guidance prefers streams where appropriate.
- Do not design for multiple streamers or per-stream sessions.
- Do not add richer admin/reporting features beyond donation list + replay.
- Do not add extra payment methods beyond QRIS.
- Do not introduce a separate queue service or external broker unless the simple single-node LiveView + PubSub approach proves insufficient.

## Topic Docs

- [Elixir Guideline](docs/elixir-guide.md)
- [Mix Guideline](docs/mix-guide.md)
- [Phoenix v1.8 Guidelines](docs/phoenix-guide.md)
- [Ecto Guideline](docs/ecto-guide.md)
- [Frontend Guideline](docs/FRONTEND.md)
- [Design Guideline](docs/DESIGN.md)
- [Testing Guideline](docs/test-guide.md)

<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->


<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->

<!-- phoenix:phoenix-end -->

<!-- phoenix:ecto-start -->
