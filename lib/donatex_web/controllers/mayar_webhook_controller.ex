defmodule DonatexWeb.MayarWebhookController do
  use DonatexWeb, :controller

  def create(conn, _params) do
    json(conn, %{ok: true})
  end
end
