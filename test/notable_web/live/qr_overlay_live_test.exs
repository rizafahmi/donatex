defmodule NotableWeb.QrOverlayLiveTest do
  use NotableWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Notable.Reactions

  describe "GET /qr-overlay" do
    test "renders the QR code and overlay float layer", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/qr-overlay")

      assert html =~ "qr-overlay-page"
      assert has_element?(view, "#qr-overlay-page")
      assert has_element?(view, "#qr-code.qr-scannable-card")
      assert has_element?(view, ".qr-overlay-floats")
    end

    test "the QR canvas carries its own hook so it animates on this page too", %{conn: conn} do
      # This page has no page-level hook, so the canvas has to bring its own.
      {:ok, view, _html} = live(conn, ~p"/qr-overlay")

      assert has_element?(view, "canvas#qr-canvas[phx-hook='QrCanvas']")
      assert has_element?(view, "#qr-svg-hidden svg")
    end

    test "renders SEO metadata with noindex robots and self-referential canonical", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/qr-overlay")

      assert html =~ ~s(<meta name="robots" content="noindex, nofollow")
      assert html =~ ~s(<link rel="canonical" href="http://localhost:4000/qr-overlay")
    end

    test "does not render flash or connection status banners", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/qr-overlay")

      refute has_element?(view, "#flash-group")
      refute has_element?(view, "#client-error")
      refute has_element?(view, "#server-error")
    end
  end

  describe "free Note floats" do
    test "shows an emoji-only float for an accepted free Note", %{conn: conn} do
      {:ok, feedback} =
        Notable.Donations.create_feedback(%{
          donor_name: "FloatSender",
          reaction: "good",
          message: "secret note body"
        })

      {:ok, view, _html} = live(conn, ~p"/qr-overlay")

      Phoenix.PubSub.broadcast(
        Notable.PubSub,
        "donations:created",
        {:donation_created, feedback}
      )

      html = render(view)
      assert html =~ ~s(id="obs-float-#{feedback.id}")
      assert float_emoji(html, feedback.id) in Reactions.pool("good")
      # The combined page is QR-only; it must not leak the note body or sender.
      refute html =~ "FloatSender"
      refute html =~ "secret note body"
    end

    test "animates a free Note float for three to four seconds", %{conn: conn} do
      {:ok, feedback} =
        Notable.Donations.create_feedback(%{donor_name: "Timed", reaction: "great", message: nil})

      {:ok, view, _html} = live(conn, ~p"/qr-overlay")

      Phoenix.PubSub.broadcast(
        Notable.PubSub,
        "donations:created",
        {:donation_created, feedback}
      )

      float_html = view |> element("#obs-float-#{feedback.id}") |> render()
      assert [_, duration] = Regex.run(~r/--float-duration: (\d+)ms/, float_html)
      assert String.to_integer(duration) in 3_000..4_000
    end

    test "does not float pending tip creations on donations:created", %{conn: conn} do
      {:ok, pending} =
        Notable.Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-qr-overlay-no-float",
          donor_name: "Tipper",
          reaction: "great",
          amount: 10_000,
          message: "please tip celebrate"
        })

      {:ok, view, _html} = live(conn, ~p"/qr-overlay")

      Phoenix.PubSub.broadcast(
        Notable.PubSub,
        "donations:created",
        {:donation_created, pending}
      )

      html = render(view)
      refute html =~ ~s(id="obs-float-#{pending.id}")
      refute html =~ "Tipper"
    end

    test "shows multiple free Note floats simultaneously", %{conn: conn} do
      {:ok, first} =
        Notable.Donations.create_feedback(%{donor_name: "One", reaction: "ok", message: nil})

      {:ok, second} =
        Notable.Donations.create_feedback(%{donor_name: "Two", reaction: "bad", message: nil})

      {:ok, view, _html} = live(conn, ~p"/qr-overlay")

      Phoenix.PubSub.broadcast(
        Notable.PubSub,
        "donations:created",
        {:donation_created, first}
      )

      Phoenix.PubSub.broadcast(
        Notable.PubSub,
        "donations:created",
        {:donation_created, second}
      )

      html = render(view)
      assert html =~ ~s(id="obs-float-#{first.id}")
      assert html =~ ~s(id="obs-float-#{second.id}")
      assert float_emoji(html, first.id) in Reactions.pool("ok")
      assert float_emoji(html, second.id) in Reactions.pool("bad")
    end

    test "dismisses a free Note float after the float timer", %{conn: conn} do
      {:ok, feedback} =
        Notable.Donations.create_feedback(%{donor_name: "Gone", reaction: "great", message: nil})

      {:ok, view, _html} = live(conn, ~p"/qr-overlay")

      Phoenix.PubSub.broadcast(
        Notable.PubSub,
        "donations:created",
        {:donation_created, feedback}
      )

      assert render(view) =~ ~s(id="obs-float-#{feedback.id}")

      send(view.pid, {:dismiss_float, feedback.id})
      refute render(view) =~ ~s(id="obs-float-#{feedback.id}")
    end

    test "does not recover free Notes as floats on mount", %{conn: conn} do
      {:ok, feedback} =
        Notable.Donations.create_feedback(%{
          donor_name: "MissedFloat",
          reaction: "ok",
          message: "already stored"
        })

      {:ok, _view, html} = live(conn, ~p"/qr-overlay")

      refute html =~ ~s(id="obs-float-#{feedback.id}")
      refute html =~ "MissedFloat"
    end
  end

  defp float_emoji(html, id) do
    pattern = ~r/id="obs-float-#{id}"[^>]*>\s*([^\s<]+)/u

    assert [_, emoji] = Regex.run(pattern, html)
    emoji
  end
end
