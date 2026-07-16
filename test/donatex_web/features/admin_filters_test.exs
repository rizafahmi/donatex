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
        reaction: "ok",
        amount: 10_000,
        message: "hello pending"
      })

    {:ok, paid} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-test-paid",
        donor_name: "Paid Donor",
        reaction: "great",
        amount: 20_000,
        message: "hello paid"
      })

    {:ok, paid, _} = Donations.mark_paid_with_change(paid)

    {:ok, pending: pending, paid: paid}
  end

  test "default view displays all donations", %{conn: conn, pending: pending, paid: paid} do
    conn
    |> put_req_header("authorization", basic_auth_header())
    |> visit(~p"/admin")
    |> assert_has("#donation-#{paid.id}", "Paid Donor")
    |> assert_has("#donation-#{pending.id}", "Pending Donor")
  end

  test "default view includes free notes", %{conn: conn} do
    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "Free Sender",
        reaction: "good",
        message: "hello free"
      })

    conn
    |> put_req_header("authorization", basic_auth_header())
    |> visit(~p"/admin")
    |> assert_has("#donation-#{feedback.id}", "Free Sender")
  end

  test "switching filters updates the list", %{conn: conn, pending: pending, paid: paid} do
    session =
      conn
      |> put_req_header("authorization", basic_auth_header())
      |> visit(~p"/admin")

    # 1. Under all (default)
    session
    |> assert_has("#donation-#{paid.id}", "Paid Donor")
    |> assert_has("#donation-#{pending.id}", "Pending Donor")

    # 2. Click "pending" filter
    session = click_button(session, "pending")

    session
    |> assert_has("#donation-#{pending.id}", "Pending Donor")
    |> refute_has("#donation-#{paid.id}", "Paid Donor")

    # 3. Click "paid" filter
    session = click_button(session, "paid")

    session
    |> assert_has("#donation-#{paid.id}", "Paid Donor")
    |> refute_has("#donation-#{pending.id}", "Pending Donor")
  end

  test "real-time updates insert/delete donations correctly based on active filter", %{
    conn: conn,
    pending: pending,
    paid: paid
  } do
    # Mount session on /admin (defaults to all)
    session =
      conn
      |> put_req_header("authorization", basic_auth_header())
      |> visit(~p"/admin")

    # 1. Create a new pending donation. Since filter is "all", it should appear.
    {:ok, new_pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-new-pending",
        donor_name: "New Pending",
        reaction: "good",
        amount: 30_000
      })

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, new_pending}
    )

    Process.sleep(50)

    session
    |> assert_has("#donation-#{new_pending.id}", "New Pending")

    # 2. Switch to pending filter — both pending rows remain.
    session = click_button(session, "pending")

    session
    |> assert_has("#donation-#{new_pending.id}", "New Pending")
    |> assert_has("#donation-#{pending.id}", "Pending Donor")

    # 3. Pay the new_pending donation. While on "pending" filter, it should disappear.
    {:ok, paid_new_pending, _} = Donations.mark_paid_with_change(new_pending)

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:paid",
      {:donation_paid, DonatexWeb.DonationPresenter.payload(paid_new_pending)}
    )

    Process.sleep(50)

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
