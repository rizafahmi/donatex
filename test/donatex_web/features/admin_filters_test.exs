defmodule DonatexWeb.AdminFiltersTest do
  use DonatexWeb.ConnCase, async: false

  alias Donatex.Config
  alias Donatex.Donations

  setup do
    # Create one paid and one pending donation for testing filters
    {:ok, pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-test-pending",
        donor_name: "Pending Donor",
        amount: 10_000,
        message: "hello pending"
      })

    {:ok, paid} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-test-paid",
        donor_name: "Paid Donor",
        amount: 20_000,
        message: "hello paid"
      })

    {:ok, paid, _} = Donations.mark_paid_with_change(paid)

    {:ok, pending: pending, paid: paid}
  end

  test "default view displays only paid donations", %{conn: conn, pending: pending, paid: paid} do
    conn
    |> put_req_header("authorization", basic_auth_header())
    |> visit(~p"/admin")
    # Should display the paid donation
    |> assert_has("#donation-#{paid.id}", "Paid Donor")
    # Should NOT display the pending donation
    |> refute_has("#donation-#{pending.id}", "Pending Donor")
  end

  test "switching filters updates the list", %{conn: conn, pending: pending, paid: paid} do
    session =
      conn
      |> put_req_header("authorization", basic_auth_header())
      |> visit(~p"/admin")

    # 1. Under paid (default)
    session
    |> assert_has("#donation-#{paid.id}", "Paid Donor")
    |> refute_has("#donation-#{pending.id}", "Pending Donor")

    # 2. Click "pending" filter
    session = click_button(session, "pending")

    session
    |> assert_has("#donation-#{pending.id}", "Pending Donor")
    |> refute_has("#donation-#{paid.id}", "Paid Donor")

    # 3. Click "all" filter
    session = click_button(session, "all")

    session
    |> assert_has("#donation-#{paid.id}", "Paid Donor")
    |> assert_has("#donation-#{pending.id}", "Pending Donor")
  end

  test "real-time updates insert/delete donations correctly based on active filter", %{
    conn: conn,
    pending: pending,
    paid: paid
  } do
    # Mount session on /admin (which defaults to paid)
    session =
      conn
      |> put_req_header("authorization", basic_auth_header())
      |> visit(~p"/admin")

    # 1. Create a new pending donation. Since filter is "paid", it should NOT appear on screen.
    {:ok, new_pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-new-pending",
        donor_name: "New Pending",
        amount: 30_000
      })

    # Broadcast creation (simulate what application does)
    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, new_pending}
    )

    # Allow LiveView process to handle PubSub message
    Process.sleep(50)

    session
    |> refute_has("#donation-#{new_pending.id}", "New Pending")

    # 2. Switch to pending filter, new_pending should not be in stream because we just switched (reset: true).
    # But wait, switching filter calls list_donations("pending") which will fetch it from DB!
    session = click_button(session, "pending")

    session
    |> assert_has("#donation-#{new_pending.id}", "New Pending")
    |> assert_has("#donation-#{pending.id}", "Pending Donor")

    # 3. Now let's pay the new_pending donation. While on "pending" filter, it should disappear!
    {:ok, paid_new_pending, _} = Donations.mark_paid_with_change(new_pending)

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:paid",
      {:donation_paid, DonatexWeb.DonationPresenter.payload(paid_new_pending)}
    )

    Process.sleep(50)

    # It should have disappeared from the pending view
    session
    |> refute_has("#donation-#{new_pending.id}", "New Pending")

    # 4. Switch to paid filter. The paid_new_pending should be there.
    session = click_button(session, "paid")

    session
    |> assert_has("#donation-#{new_pending.id}", "New Pending")
    |> assert_has("#donation-#{paid.id}", "Paid Donor")
  end

  defp basic_auth_header do
    "Basic " <> Base.encode64("#{Config.admin_username()}:#{Config.admin_password()}")
  end
end
