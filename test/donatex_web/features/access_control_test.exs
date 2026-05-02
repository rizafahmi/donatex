defmodule DonatexWeb.AccessControlTest do
  use DonatexWeb.ConnCase, async: true

  import Plug.Conn

  alias Donatex.Config

  test "overlay route rejects invalid token with 404", %{conn: conn} do
    conn
    |> visit(~p"/overlay/not-the-token")
    |> unwrap(fn conn ->
      assert conn.status == 404
      conn
    end)
  end

  test "overlay route mounts with the configured token", %{conn: conn} do
    conn
    |> visit(~p"/overlay/#{Config.overlay_token()}")
    |> assert_has("h1", "Overlay")
  end

  test "admin route requires basic auth", %{conn: conn} do
    conn
    |> visit(~p"/admin")
    |> unwrap(fn conn ->
      assert conn.status == 401
      assert get_resp_header(conn, "www-authenticate") != []
      conn
    end)
  end

  test "admin route rejects invalid basic auth credentials", %{conn: conn} do
    conn
    |> put_req_header("authorization", basic_auth_header("wrong", "wrong"))
    |> visit(~p"/admin")
    |> unwrap(fn conn ->
      assert conn.status == 401
      conn
    end)
  end

  test "admin route accepts valid basic auth credentials", %{conn: conn} do
    conn
    |> put_req_header(
      "authorization",
      basic_auth_header(Config.admin_username(), Config.admin_password())
    )
    |> visit(~p"/admin")
    |> assert_has("h1", "Admin")
  end

  defp basic_auth_header(username, password) do
    "Basic " <> Base.encode64("#{username}:#{password}")
  end
end
