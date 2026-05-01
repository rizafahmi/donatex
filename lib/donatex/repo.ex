defmodule Donatex.Repo do
  use Ecto.Repo,
    otp_app: :donatex,
    adapter: Ecto.Adapters.SQLite3
end
