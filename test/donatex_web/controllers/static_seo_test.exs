defmodule DonatexWeb.StaticSeoTest do
  use DonatexWeb.ConnCase, async: true

  test "serves robots.txt", %{conn: conn} do
    conn = get(conn, "/robots.txt")
    body = response(conn, 200)
    assert body =~ "robots.txt"
    assert body =~ "Sitemap: https://feedback.rizafahmi.com/sitemap.xml"
    assert body =~ "Disallow: /admin"
    assert body =~ "Disallow: /overlay"
    assert body =~ "Disallow: /api"
  end

  test "serves sitemap.xml", %{conn: conn} do
    conn = get(conn, "/sitemap.xml")
    body = response(conn, 200)
    assert body =~ "<urlset"
    assert body =~ "https://feedback.rizafahmi.com/"
    refute body =~ "https://feedback.rizafahmi.com/overlay"
  end

  test "serves llms.txt", %{conn: conn} do
    conn = get(conn, "/llms.txt")
    body = response(conn, 200)
    assert body =~ "# Notable"
    assert body =~ "Kirim Feedback & Tips"
    assert body =~ "OBS Overlay"
    assert body =~ "Tanya Jawab"
    assert body =~ "/questions"
  end

  test "returns 301 permanent redirect for /donate", %{conn: conn} do
    conn = get(conn, "/donate")
    assert conn.status == 301
    assert redirected_to(conn, 301) == "/"
  end

  test "verifies security headers are set including strict-transport-security", %{conn: conn} do
    conn = get(conn, "/")

    assert get_resp_header(conn, "strict-transport-security") == [
             "max-age=31536000; includeSubDomains"
           ]

    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    assert get_resp_header(conn, "x-frame-options") == ["DENY"]
  end
end
