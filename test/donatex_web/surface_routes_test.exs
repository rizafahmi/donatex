defmodule DonatexWeb.SurfaceRoutesTest do
  use DonatexWeb.ConnCase, async: true

  test "GET /donate", %{conn: conn} do
    conn
    |> visit("/donate")
    |> assert_has("h1", "Donate")
  end

  test "GET /overlay/:token", %{conn: conn} do
    token = "test-token"

    conn
    |> visit("/overlay/#{token}")
    |> assert_has("h1", "Overlay")
  end

  test "GET /admin", %{conn: conn} do
    conn
    |> visit("/admin")
    |> assert_has("h1", "Admin")
  end

  test "POST /webhooks/mayar", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar", %{"event" => "payment.received"})

    assert json_response(conn, 200) == %{"ok" => true}
  end
end
