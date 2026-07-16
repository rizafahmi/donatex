defmodule DonatexWeb.AdminReplayTest do
  use DonatexWeb.ConnCase, async: false

  import Plug.Conn

  alias Donatex.Config
  alias Donatex.Donations
  alias Donatex.Donations.Donation
  alias Donatex.Repo

  test "replay broadcasts a donation without resetting alerted", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    {:ok, _pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-admin-1",
        donor_name: "E",
        reaction: "good",
        amount: 15_000
      })

    {:ok, %Donation{} = donation} = Donations.mark_paid_by_mayar_transaction_id("tx-admin-1")
    {:ok, _} = Donations.mark_donation_alerted(donation)
    donation_id = donation.id

    conn
    |> put_req_header(
      "authorization",
      basic_auth_header(Config.admin_username(), Config.admin_password())
    )
    |> visit(~p"/admin")
    |> assert_has("#donation-#{donation.id}", "E")
    |> within("#donations-#{donation.id}", fn session ->
      session |> click_button("Replay")
    end)

    assert_received {:donation_paid, %{id: ^donation_id}}

    assert Repo.get!(Donation, donation_id).alerted
  end

  test "does not offer replay for free notes", %{conn: conn} do
    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "Free Replay",
        reaction: "ok",
        message: "no tip"
      })

    conn
    |> put_req_header(
      "authorization",
      basic_auth_header(Config.admin_username(), Config.admin_password())
    )
    |> visit(~p"/admin")
    |> assert_has("#donation-#{feedback.id}", "Free Replay")
    |> within("#donations-#{feedback.id}", fn session ->
      refute_has(session, "button", "Replay Alert")
    end)
  end

  defp basic_auth_header(username, password) do
    "Basic " <> Base.encode64("#{username}:#{password}")
  end
end
