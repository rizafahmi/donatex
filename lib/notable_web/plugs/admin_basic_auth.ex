defmodule NotableWeb.Plugs.AdminBasicAuth do
  @moduledoc false

  alias Notable.Config

  def init(opts), do: opts

  def call(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn,
      username: Config.admin_username(),
      password: Config.admin_password()
    )
    |> stamp_admin_session()
  end

  # Plug.BasicAuth halts with a 401 on failed credentials, so this stamp is
  # only reached when Basic Auth succeeded. The session is already fetched
  # by the :browser pipeline, so it is available to write here and survives
  # into the LiveView websocket mount where LiveAdminAuth reads it.
  defp stamp_admin_session(%Plug.Conn{halted: true} = conn), do: conn
  defp stamp_admin_session(conn), do: Plug.Conn.put_session(conn, :admin_authenticated, true)
end
