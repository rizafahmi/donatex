defmodule DonatexWeb.Plugs.MayarWebhookAuth do
  @moduledoc false

  import Plug.Conn

  require Logger

  alias Donatex.Mayar.WebhookAuth

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.params do
      %{"token" => token} ->
        if WebhookAuth.valid_token?(token) do
          conn
        else
          reject(conn, "invalid token")
        end

      _params ->
        reject(conn, "missing token")
    end
  end

  defp reject(conn, reason) do
    Logger.warning("Mayar webhook rejected #{reason} remote_ip=#{format_remote_ip(conn)}")
    conn |> send_resp(404, "Not Found") |> halt()
  end

  defp format_remote_ip(%Plug.Conn{remote_ip: remote_ip}) when is_tuple(remote_ip) do
    remote_ip
    |> :inet.ntoa()
    |> to_string()
  rescue
    _ -> "unknown"
  end

  defp format_remote_ip(_conn), do: "unknown"
end
