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
| `OVERLAY_TOKEN` | Non-guessable token used by `/overlay/:token` |
| `ADMIN_USERNAME` | Basic auth username for `/admin` |
| `ADMIN_PASSWORD` | Basic auth password for `/admin` |
| `DONATEX_BASE_URL` | Public base URL of this app (used to build public links) |

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
