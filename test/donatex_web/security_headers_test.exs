defmodule DonatexWeb.SecurityHeadersTest do
  use DonatexWeb.ConnCase

  test "sets security headers", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert ["DENY"] = get_resp_header(conn, "x-frame-options")
    assert ["strict-origin-when-cross-origin"] = get_resp_header(conn, "referrer-policy")

    assert ["camera=(), microphone=(), geolocation=()"] =
             get_resp_header(conn, "permissions-policy")

    assert [csp] = get_resp_header(conn, "content-security-policy")
    assert csp =~ "script-src 'self' 'sha256-EVYDGHSK/rxwzu+pTaoqPoOXtDc/oiZPntzv6wWXhj8='"
    refute csp =~ "script-src 'self' 'unsafe-inline'"
  end
end
