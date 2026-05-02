defmodule DonatexWeb.OverlayLiveTest do
  use DonatexWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Donatex.Config
  alias Donatex.Donations
  alias Donatex.Donations.Donation
  alias Donatex.Repo

  test "replays paid and unalerted donations on mount and advances after dismiss", %{conn: conn} do
    {:ok, first_pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-1",
        donor_name: "A",
        amount: 10_000
      })

    {:ok, second_pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-2",
        donor_name: "B",
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

    {:ok, view, _html} = live(conn, ~p"/overlay/#{Config.overlay_token()}")

    assert has_element?(view, "p.mt-2.text-xl", "A")
    refute has_element?(view, "p.mt-2.text-xl", "B")

    send(view.pid, {:dismiss_current, first.id})
    render(view)
    assert has_element?(view, "p.mt-2.text-xl", "B")

    assert Repo.get!(Donation, first.id).alerted

    send(view.pid, {:dismiss_current, second.id})
    render(view)
    assert has_element?(view, "h1", "Overlay")

    assert Repo.get!(Donation, second.id).alerted
  end

  test "queues paid events received while another alert is displayed", %{conn: conn} do
    {:ok, _pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-3",
        donor_name: "C",
        amount: 15_000
      })

    {:ok, _pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-overlay-4",
        donor_name: "D",
        amount: 25_000
      })

    {:ok, first} = Donations.mark_paid_by_mayar_transaction_id("tx-overlay-3")
    {:ok, second} = Donations.mark_paid_by_mayar_transaction_id("tx-overlay-4")

    {:ok, _} = Donations.mark_donation_alerted(first)
    {:ok, _} = Donations.mark_donation_alerted(second)

    {:ok, view, _html} = live(conn, ~p"/overlay/#{Config.overlay_token()}")
    assert has_element?(view, "h1", "Overlay")

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:paid",
      {:donation_paid, donation_payload(first)}
    )

    render(view)
    assert has_element?(view, "p.mt-2.text-xl", "C")

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:paid",
      {:donation_paid, donation_payload(second)}
    )

    render(view)
    assert has_element?(view, "p.mt-2.text-xl", "C")
    refute has_element?(view, "p.mt-2.text-xl", "D")

    send(view.pid, {:dismiss_current, first.id})
    render(view)
    assert has_element?(view, "p.mt-2.text-xl", "D")
  end

  defp donation_payload(donation) do
    %{
      id: donation.id,
      mayar_transaction_id: donation.mayar_transaction_id,
      donor_name: donation.donor_name,
      amount: donation.amount,
      message: donation.message,
      inserted_at: donation.inserted_at
    }
  end
end
