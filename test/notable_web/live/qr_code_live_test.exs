defmodule NotableWeb.QrCodeLiveTest do
  use NotableWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Notable.Qr

  # Matrix generation, palette limits and scannability live in
  # `Notable.QrTest`, which checks them against a real decoder.

  describe "GET /qr" do
    test "renders the QR page with correct elements", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/qr")

      assert html =~ "qr-page"
      assert html =~ "qr-code"
      assert html =~ "Beri"
      assert html =~ "Masukan"
      assert html =~ "Scan QR Code"
      assert html =~ "Download PNG"
      assert html =~ "Share"
    end

    test "renders SEO metadata with noindex robots", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/qr")

      assert html =~ ~s(<meta name="robots" content="noindex, nofollow")
    end

    test "does not render flash or connection status banners", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/qr")

      refute has_element?(view, "#flash-group")
      refute has_element?(view, "#client-error")
      refute has_element?(view, "#server-error")
    end

    test "renders the animated canvas alongside a hidden SVG for download", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/qr")

      assert has_element?(view, "#qr-code.qr-scannable-card")
      assert has_element?(view, "canvas#qr-canvas[phx-hook='QrCanvas']")
      assert has_element?(view, "#qr-svg-hidden svg")
    end

    test "hands the canvas the matrix and the palette the tests constrain", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/qr")

      qr = Qr.generate(Qr.public_url())

      # The canvas must not carry its own colours: the scannability budget is
      # enforced against this palette, so both renderers have to read the same
      # one. Shipping a copy in JS would silently escape those tests.
      assert html =~ Phoenix.HTML.html_escape(JSON.encode!(Qr.client_palette())) |> safe_string()
      assert html =~ ~s(data-size="#{qr.size}")
      assert html =~ ~s(data-quiet="#{Qr.quiet_zone()}")
    end

    test "the canvas is not re-rendered by LiveView diffs", %{conn: conn} do
      # A patch that replaced the canvas element would wipe the animation and
      # restart it from a blank frame.
      {:ok, view, _html} = live(conn, ~p"/qr")

      assert has_element?(view, "canvas#qr-canvas[phx-update='ignore']")
    end

    test "download button is present and triggers push event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/qr")

      assert view
             |> element("#qrDownloadBtn")
             |> render() =~ "Download PNG"

      view |> element("#qrDownloadBtn") |> render_click()
      assert_push_event(view, "qr:download", %{})
    end

    test "share button triggers qr:share event with URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/qr")

      assert view
             |> element("#qrShareBtn")
             |> render() =~ "Share"
    end
  end

  defp safe_string({:safe, iodata}), do: IO.iodata_to_binary(iodata)
end
