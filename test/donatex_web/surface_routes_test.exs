defmodule DonatexWeb.SurfaceRoutesTest do
  use DonatexWeb.ConnCase, async: true

  alias Donatex.Config

  test "GET /donate", %{conn: conn} do
    conn
    |> visit("/donate")
    |> assert_has("h1", "Donate")
  end

  test "GET /overlay/:token", %{conn: conn} do
    token = Config.overlay_token()

    conn
    |> visit("/overlay/#{token}")
    |> assert_has("h1", "Overlay")
  end

  test "GET /admin", %{conn: conn} do
    conn
    |> put_req_header("authorization", basic_auth_header())
    |> visit("/admin")
    |> assert_has("h1", "Admin")
  end

  test "POST /webhooks/mayar/:token", %{conn: conn} do
    token = Config.mayar_webhook_token()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{token}", %{"event" => "payment.received"})

    assert json_response(conn, 200) == %{"ok" => true}
  end

  defp basic_auth_header do
    "Basic " <> Base.encode64("#{Config.admin_username()}:#{Config.admin_password()}")
  end
end
