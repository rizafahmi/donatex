defmodule Notable.Repo do
  use Ecto.Repo,
    otp_app: :notable,
    adapter: Ecto.Adapters.SQLite3
end
