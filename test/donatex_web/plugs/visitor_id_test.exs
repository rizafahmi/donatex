defmodule DonatexWeb.Plugs.VisitorIdTest do
  use DonatexWeb.ConnCase, async: true

  import Plug.Test, only: [put_peer_data: 2]

  alias DonatexWeb.Plugs.VisitorId

  test "creates an opaque URL-safe ID without storing request identity", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> put_peer_data(%{address: {203, 0, 113, 42}, port: 48_123, ssl_cert: nil})
      |> put_req_header("user-agent", "Visitor Browser")
      |> VisitorId.call([])

    visitor_id = get_session(conn, "visitor_id")

    assert visitor_id =~ ~r/^[A-Za-z0-9_-]{22}$/
    assert get_session(conn) == %{"visitor_id" => visitor_id}
    refute visitor_id =~ "203"
    refute visitor_id =~ "Visitor"
  end

  test "preserves an existing visitor ID", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{"visitor_id" => "existing-anonymous-id"})
      |> VisitorId.call([])

    assert get_session(conn, "visitor_id") == "existing-anonymous-id"
  end
end
