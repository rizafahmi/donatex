defmodule DonatexWeb.PageControllerTest do
  use DonatexWeb.ConnCase, async: true

  test "GET /donate redirects to root", %{conn: conn} do
    conn = get(conn, ~p"/donate")
    assert redirected_to(conn, 301) == ~p"/"
    assert conn.status == 301
  end
end
