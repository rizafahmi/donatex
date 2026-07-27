defmodule DonatexWeb.OverlayLiveTest do
  use DonatexWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Donatex.Donations
  alias Donatex.Donations.Donation
  alias Donatex.Reactions
  alias Donatex.Repo
  alias Ecto.Adapters.SQL

  test "renders SEO metadata with noindex robots and self-referential canonical URL", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, ~p"/overlay")

    assert html =~ ~s(<meta name="robots" content="noindex, nofollow")
    assert html =~ ~s(<link rel="canonical" href="http://localhost:4000/overlay")
  end

  test "does not render flash or connection status banners", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/overlay")

    refute has_element?(view, "#flash-group")
    refute has_element?(view, "#client-error")
    refute has_element?(view, "#server-error")
  end

  test "replays paid and unalerted donations on mount and advances after dismiss", %{conn: conn} do
    {:ok, first_pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-1",
        donor_name: "A",
        reaction: "good",
        amount: 10_000
      })

    {:ok, second_pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-2",
        donor_name: "B",
        reaction: "great",
        amount: 20_000
      })

    {:ok, first} = Donations.mark_paid_by_mayar_transaction_id(first_pending.mayar_transaction_id)

    {:ok, second} =
      Donations.mark_paid_by_mayar_transaction_id(second_pending.mayar_transaction_id)

    Repo.update_all(from(d in Donation, where: d.id == ^first.id),
      set: [inserted_at: ~U[2020-01-01 00:00:01Z]]
    )

    Repo.update_all(from(d in Donation, where: d.id == ^second.id),
      set: [inserted_at: ~U[2020-01-01 00:00:02Z]]
    )

    {:ok, view, _html} = live(conn, ~p"/overlay")

    assert has_element?(view, "div.obs-overlay-main-text", "A")
    refute has_element?(view, "div.obs-overlay-main-text", "B")

    send(view.pid, {:dismiss_current, first.id})
    render(view)
    assert has_element?(view, "div.obs-overlay-main-text", "B")

    assert Repo.get!(Donation, first.id).alerted

    send(view.pid, {:dismiss_current, second.id})
    render(view)
    assert has_element?(view, "h1", "Overlay")

    assert Repo.get!(Donation, second.id).alerted
  end

  test "keeps the current alert when acknowledgement persistence fails", %{conn: conn} do
    {:ok, first_pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-failure-1",
        donor_name: "Failed Acknowledgement",
        reaction: "good",
        amount: 10_000
      })

    {:ok, second_pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-failure-2",
        donor_name: "Queued Alert",
        reaction: "great",
        amount: 20_000
      })

    {:ok, first} = Donations.mark_paid_by_mayar_transaction_id(first_pending.mayar_transaction_id)

    {:ok, second} =
      Donations.mark_paid_by_mayar_transaction_id(second_pending.mayar_transaction_id)

    Repo.update_all(from(d in Donation, where: d.id == ^first.id),
      set: [inserted_at: ~U[2020-01-01 00:00:01Z]]
    )

    Repo.update_all(from(d in Donation, where: d.id == ^second.id),
      set: [inserted_at: ~U[2020-01-01 00:00:02Z]]
    )

    {:ok, view, _html} = live(conn, ~p"/overlay")

    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:alerted")

    SQL.query!(
      Repo,
      """
      CREATE TEMPORARY TRIGGER prevent_alerted_update
      UPDATE OF alerted ON donations
      WHEN NEW.alerted = 1
      BEGIN
        SELECT RAISE(ABORT, 'test_forced_failure');
      END
      """
    )

    try do
      send(view.pid, {:dismiss_current, first.id})
      render(view)

      assert has_element?(view, "div.obs-overlay-main-text", "Failed Acknowledgement")
      refute has_element?(view, "div.obs-overlay-main-text", "Queued Alert")

      first_id = first.id
      refute_receive {:donation_alerted, %{id: ^first_id}}

      recovered_ids = Enum.map(Donations.list_paid_unalerted_donations(), & &1.id)
      assert first.id in recovered_ids
      assert second.id in recovered_ids
      refute Repo.get!(Donation, first.id).alerted
    after
      SQL.query!(Repo, "DROP TRIGGER IF EXISTS prevent_alerted_update")
    end
  end

  test "brands the tip alert title bar as Notable", %{conn: conn} do
    {:ok, pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-brand",
        donor_name: "Branded Tipper",
        reaction: "great",
        amount: 10_000
      })

    {:ok, _paid} = Donations.mark_paid_by_mayar_transaction_id(pending.mayar_transaction_id)
    {:ok, _view, html} = live(conn, ~p"/overlay")

    assert html =~ "notable-terminal | alert"
    refute html =~ "donatex-terminal | alert"
  end

  test "queues paid events received while another alert is displayed", %{conn: conn} do
    {:ok, _pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-3",
        donor_name: "C",
        reaction: "ok",
        amount: 15_000
      })

    {:ok, _pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-4",
        donor_name: "D",
        reaction: "bad",
        amount: 25_000
      })

    {:ok, first} = Donations.mark_paid_by_mayar_transaction_id("tx-overlay-3")
    {:ok, second} = Donations.mark_paid_by_mayar_transaction_id("tx-overlay-4")

    {:ok, _} = Donations.mark_donation_alerted(first)
    {:ok, _} = Donations.mark_donation_alerted(second)

    {:ok, view, _html} = live(conn, ~p"/overlay")
    assert has_element?(view, "h1", "Overlay")

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:paid",
      {:donation_paid, donation_payload(first)}
    )

    render(view)
    assert has_element?(view, "div.obs-overlay-main-text", "C")

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:paid",
      {:donation_paid, donation_payload(second)}
    )

    render(view)
    assert has_element?(view, "div.obs-overlay-main-text", "C")
    refute has_element?(view, "div.obs-overlay-main-text", "D")

    send(view.pid, {:dismiss_current, first.id})
    render(view)
    assert has_element?(view, "div.obs-overlay-main-text", "D")
  end

  test "shows an emoji-only float for an accepted free Note", %{conn: conn} do
    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "FloatSender",
        reaction: "good",
        message: "secret note body"
      })

    {:ok, view, _html} = live(conn, ~p"/overlay")

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, feedback}
    )

    html = render(view)
    assert html =~ ~s(id="obs-float-#{feedback.id}")
    assert float_emoji(html, feedback.id) in Reactions.pool("good")
    refute html =~ "FloatSender"
    refute html =~ "secret note body"
  end

  test "animates a free Note float for three to four seconds", %{conn: conn} do
    {:ok, feedback} =
      Donations.create_feedback(%{donor_name: "Timed", reaction: "great", message: nil})

    {:ok, view, _html} = live(conn, ~p"/overlay")

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, feedback}
    )

    float_html = view |> element("#obs-float-#{feedback.id}") |> render()
    assert [_, duration] = Regex.run(~r/--float-duration: (\d+)ms/, float_html)
    assert String.to_integer(duration) in 3_000..4_000
  end

  test "does not float pending tip creations on donations:created", %{conn: conn} do
    {:ok, pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-no-float",
        donor_name: "Tipper",
        reaction: "great",
        amount: 10_000,
        message: "please tip celebrate"
      })

    {:ok, view, _html} = live(conn, ~p"/overlay")

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, pending}
    )

    html = render(view)
    refute html =~ ~s(id="obs-float-#{pending.id}")
    refute html =~ "Tipper"
  end

  test "shows multiple free Note floats simultaneously", %{conn: conn} do
    {:ok, first} =
      Donations.create_feedback(%{donor_name: "One", reaction: "ok", message: nil})

    {:ok, second} =
      Donations.create_feedback(%{donor_name: "Two", reaction: "bad", message: nil})

    {:ok, view, _html} = live(conn, ~p"/overlay")

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, first}
    )

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
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
      Donations.create_feedback(%{donor_name: "Gone", reaction: "great", message: nil})

    {:ok, view, _html} = live(conn, ~p"/overlay")

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, feedback}
    )

    assert render(view) =~ ~s(id="obs-float-#{feedback.id}")

    send(view.pid, {:dismiss_float, feedback.id})
    refute render(view) =~ ~s(id="obs-float-#{feedback.id}")
  end

  test "free Note float does not become a tip celebration", %{conn: conn} do
    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "NoCelebrate",
        reaction: "good",
        message: "keep ambient"
      })

    {:ok, view, _html} = live(conn, ~p"/overlay")

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, feedback}
    )

    html = render(view)
    assert html =~ ~s(id="obs-float-#{feedback.id}")
    refute has_element?(view, "div.obs-overlay-main-text", "NoCelebrate")
    assert has_element?(view, "h1", "Overlay")
  end

  test "does not recover free Notes as floats on overlay mount", %{conn: conn} do
    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "MissedFloat",
        reaction: "ok",
        message: "already stored"
      })

    {:ok, _view, html} = live(conn, ~p"/overlay")

    refute html =~ ~s(id="obs-float-#{feedback.id}")
    refute html =~ "MissedFloat"
  end

  test "provides static alert fallbacks when reduced motion is requested" do
    css = File.read!(Path.expand("../../../assets/css/app.css", __DIR__))

    assert [_, reduced_motion_rules] =
             Regex.run(
               ~r/@media \(prefers-reduced-motion: reduce\) \{(?<rules>.*)\}\s*\z/s,
               css
             )

    assert reduced_motion_rules =~ ".obs-float-emoji"
    assert reduced_motion_rules =~ ".obs-overlay-line"
    assert reduced_motion_rules =~ ".obs-overlay-main-text"
    assert reduced_motion_rules =~ ".obs-overlay-sub-text"
    assert reduced_motion_rules =~ "animation: none"
  end

  defp donation_payload(donation) do
    %{
      id: donation.id,
      mayar_transaction_id: donation.mayar_transaction_id,
      donor_name: donation.donor_name,
      reaction: donation.reaction,
      amount: donation.amount,
      message: donation.message,
      inserted_at: donation.inserted_at
    }
  end

  defp float_emoji(html, id) do
    pattern = ~r/id="obs-float-#{id}"[^>]*>\s*([^\s<]+)/u

    assert [_, emoji] = Regex.run(pattern, html)
    emoji
  end
end
