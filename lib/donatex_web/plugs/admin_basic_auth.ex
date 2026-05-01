defmodule DonatexWeb.Plugs.AdminBasicAuth do
  @moduledoc false

  alias Donatex.Config

  def init(opts), do: opts

  def call(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn,
      username: Config.admin_username(),
      password: Config.admin_password()
    )
  end
end
