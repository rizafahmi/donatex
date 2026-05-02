# Donatex

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Copy `.env.example` to `.env` and adjust values as needed
* Load env vars into your current shell session with `source .env`
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Environment variables

Donatex expects these values to be provided via environment variables. In development, the intended workflow is `source .env` before starting the server.

| Variable | Purpose |
| --- | --- |
| `MAYAR_API_BASE_URL` | Mayar Headless API base URL (sandbox or prod) |
| `MAYAR_API_KEY` | Mayar API key |
| `MAYAR_WEBHOOK_TOKEN` | Non-guessable token embedded in the registered Mayar webhook callback URL (recommend 20+ characters) |
| `OVERLAY_TOKEN` | Non-guessable token used by `/overlay/:token` (recommend 20+ characters) |
| `ADMIN_USERNAME` | Basic auth username for `/admin` |
| `ADMIN_PASSWORD` | Basic auth password for `/admin` |
| `DONATEX_BASE_URL` | Public base URL of this app (used to build public links) |
| `PHX_HOST` | Public host used by Phoenix endpoint URL config (prod) |
| `SECRET_KEY_BASE` | Required in production; generate with `mix phx.gen.secret` |
| `DATABASE_PATH` | Absolute path to SQLite DB file (prod) |
| `PORT` | Server port (defaults to 4000) |
| `PHX_SERVER` | Set to `true` when running as a server in production |
| `POOL_SIZE` | Repo pool size (defaults to 5) |

## Mayar Webhook Authenticity

The official Mayar webhook docs reviewed for this project describe webhook setup, payloads, and management endpoints, but they do not document a request signature header, shared secret, or HMAC verification algorithm.

- Integration guide: `https://docs.mayar.id/integration/webhook`
- Register endpoint: `https://docs.mayar.id/api-reference/webhook/registerurlhook`

For the MVP, Donatex will treat webhook authenticity as a URL-secret model:

- Register an HTTPS callback URL that contains `MAYAR_WEBHOOK_TOKEN` in a non-guessable path segment.
- Reject webhook requests whose token does not match before any DB writes or PubSub broadcasts.
- Still validate payload shape and correlate the event to an existing donation row.

This is weaker than signed webhooks because it does not provide message integrity. If Mayar later documents official request signing, Donatex should replace the URL-secret fallback with that mechanism.

## Setup & Deployment

See [OPERATIONS.md](docs/OPERATIONS.md) for:

- webhook callback URL format and registration steps
- overlay/admin URLs to copy into OBS and your browser
- recovery behavior and webhook retry/deduping semantics
- production-only env vars (`DATABASE_PATH`, `SECRET_KEY_BASE`, `PHX_HOST`, etc.)

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
