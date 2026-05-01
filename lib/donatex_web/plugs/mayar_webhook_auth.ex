defmodule DonatexWeb.Plugs.MayarWebhookAuth do
  @moduledoc false

  import Plug.Conn

  alias Donatex.Mayar.WebhookAuth

  def init(opts), do: opts

  def call(%Plug.Conn{params: %{"token" => token}} = conn, _opts) do
    if WebhookAuth.valid_token?(token) do
      conn
    else
      conn |> send_resp(404, "Not Found") |> halt()
    end
  end

  def call(conn, _opts), do: conn |> send_resp(404, "Not Found") |> halt()
end
