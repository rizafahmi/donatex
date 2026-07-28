defmodule DonatexWeb.AccessControlTest do
  use DonatexWeb.ConnCase, async: true

  import Plug.Conn

  alias Donatex.Config

  describe "LiveView admin re-auth on mount" do
    # A LiveView websocket mount/reconnect bypasses the plug pipeline, so the
    # admin gate must be re-enforced by an `on_mount` callback. The plug only
    # guards the initial HTTP request.
    test "on_mount halts and redirects home when admin session flag is absent" do
      assert {:halt, socket} =
               DonatexWeb.LiveAdminAuth.on_mount(:default, %{}, %{}, %Phoenix.LiveView.Socket{})

      assert socket.redirected == {:redirect, %{status: 302, to: "/"}}
    end

    test "on_mount halts and redirects home when admin session flag is explicitly false" do
      assert {:halt, socket} =
               DonatexWeb.LiveAdminAuth.on_mount(
                 :default,
                 %{},
                 %{"admin_authenticated" => false},
                 %Phoenix.LiveView.Socket{}
               )

      assert socket.redirected == {:redirect, %{status: 302, to: "/"}}
    end

    test "on_mount continues when admin session flag is present" do
      socket = %Phoenix.LiveView.Socket{assigns: %{flash: %{}}}

      assert {:cont, ^socket} =
               DonatexWeb.LiveAdminAuth.on_mount(
                 :default,
                 %{},
                 %{"admin_authenticated" => true},
                 socket
               )
    end
  end

  test "overlay route valid", %{conn: conn} do
    conn
    |> visit(~p"/overlay")
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

    seo_conn =
      conn
      |> put_req_header(
        "authorization",
        basic_auth_header(Config.admin_username(), Config.admin_password())
      )
      |> get(~p"/admin")

    html = html_response(seo_conn, 200)
    assert html =~ ~s(<meta name="robots" content="noindex, nofollow")
    assert html =~ ~s(<link rel="canonical" href="http://localhost:4000/admin")
  end

  defp basic_auth_header(username, password) do
    "Basic " <> Base.encode64("#{username}:#{password}")
  end
end
