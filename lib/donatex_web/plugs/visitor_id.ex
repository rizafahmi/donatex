defmodule DonatexWeb.Plugs.VisitorId do
  @moduledoc "Ensures each signed browser session has an opaque visitor identifier."

  @behaviour Plug

  import Plug.Conn

  @session_key "visitor_id"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_session(conn, @session_key) do
      visitor_id when is_binary(visitor_id) and visitor_id != "" ->
        conn

      _missing ->
        put_session(conn, @session_key, generate_visitor_id())
    end
  end

  defp generate_visitor_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
