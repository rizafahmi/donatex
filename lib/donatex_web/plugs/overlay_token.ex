defmodule DonatexWeb.Plugs.OverlayToken do
  @moduledoc false

  import Plug.Conn

  alias Donatex.Config

  def init(opts), do: opts

  def call(%Plug.Conn{params: %{"token" => token}} = conn, _opts) when is_binary(token) do
    if Plug.Crypto.secure_compare(token, Config.overlay_token()) do
      conn
    else
      conn |> send_resp(404, "Not Found") |> halt()
    end
  end

  def call(conn, _opts), do: conn |> send_resp(404, "Not Found") |> halt()
end
