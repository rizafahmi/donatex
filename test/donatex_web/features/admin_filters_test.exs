defmodule DonatexWeb.AdminFiltersTest do
  use DonatexWeb.ConnCase, async: false

  alias Donatex.Config
  alias Donatex.Donations
  alias Donatex.Donations.Donation
  alias Donatex.Repo

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

  test "empty state uses notes-oriented copy", %{conn: conn} do
    Repo.delete_all(Donation)

    conn
    |> put_req_header("authorization", basic_auth_header())
    |> visit(~p"/admin")
    |> assert_has("#donations-empty", "No notes yet")
    |> refute_has("#donations-empty", "No donations yet")
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

  test "feedback cards show reaction and type without an amount", %{conn: conn} do
    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "Card Sender",
        reaction: "good",
        message: "hello card"
      })

    conn
    |> put_req_header("authorization", basic_auth_header())
    |> visit(~p"/admin")
    |> assert_has("#donation-#{feedback.id}-reaction", "Good")
    |> assert_has("#donation-#{feedback.id}-type", "Feedback")
    |> refute_has("#donation-#{feedback.id}-amount")
  end

  test "feedback cards style the sent status", %{conn: conn} do
    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "Sent Status",
        reaction: "ok",
        message: "styled"
      })

    conn
    |> put_req_header("authorization", basic_auth_header())
    |> visit(~p"/admin")
    |> assert_has("#donation-#{feedback.id}-status[data-status=sent]", "sent")
  end

  test "tip cards show tip type and amount", %{conn: conn, paid: paid} do
    conn
    |> put_req_header("authorization", basic_auth_header())
    |> visit(~p"/admin")
    |> assert_has("#donation-#{paid.id}-reaction", "Great")
    |> assert_has("#donation-#{paid.id}-type", "Tip")
    |> assert_has("#donation-#{paid.id}-amount", "Rp 20.000")
  end

  test "cards show the note timestamp", %{conn: conn, paid: paid} do
    stamped = ~U[2026-01-02 15:30:00Z]

    {:ok, _} =
      paid
      |> Ecto.Changeset.change(%{inserted_at: stamped, updated_at: stamped})
      |> Donatex.Repo.update()

    conn
    |> put_req_header("authorization", basic_auth_header())
    |> visit(~p"/admin")
    |> assert_has("#donation-#{paid.id}-time", "2 Jan 2026, 15:30")
  end

  test "tips filter shows tips and excludes feedback", %{
    conn: conn,
    pending: pending,
    paid: paid
  } do
    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "Free Sender",
        reaction: "good",
        message: "hello free"
      })

    conn
    |> put_req_header("authorization", basic_auth_header())
    |> visit(~p"/admin")
    |> click_button("tips")
    |> assert_has("#donation-#{paid.id}", "Paid Donor")
    |> assert_has("#donation-#{pending.id}", "Pending Donor")
    |> refute_has("#donation-#{feedback.id}", "Free Sender")
  end

  test "feedback filter shows free notes and excludes tips", %{
    conn: conn,
    pending: pending,
    paid: paid
  } do
    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "Free Sender",
        reaction: "good",
        message: "hello free"
      })

    conn
    |> put_req_header("authorization", basic_auth_header())
    |> visit(~p"/admin")
    |> click_button("feedback")
    |> assert_has("#donation-#{feedback.id}", "Free Sender")
    |> refute_has("#donation-#{paid.id}", "Paid Donor")
    |> refute_has("#donation-#{pending.id}", "Pending Donor")
  end

  test "switching filters updates the list", %{conn: conn, pending: pending, paid: paid} do
    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "Free Sender",
        reaction: "good",
        message: "hello free"
      })

    session =
      conn
      |> put_req_header("authorization", basic_auth_header())
      |> visit(~p"/admin")

    session
    |> assert_has("button[phx-value-filter=all]")
    |> assert_has("button[phx-value-filter=tips]")
    |> assert_has("button[phx-value-filter=feedback]")
    |> refute_has("button[phx-value-filter=paid]")
    |> refute_has("button[phx-value-filter=pending]")

    # 1. Under all (default)
    session
    |> assert_has("#donation-#{paid.id}", "Paid Donor")
    |> assert_has("#donation-#{pending.id}", "Pending Donor")
    |> assert_has("#donation-#{feedback.id}", "Free Sender")

    # 2. Tips filter
    session = click_button(session, "tips")

    session
    |> assert_has("#donation-#{paid.id}", "Paid Donor")
    |> assert_has("#donation-#{pending.id}", "Pending Donor")
    |> refute_has("#donation-#{feedback.id}", "Free Sender")

    # 3. Feedback filter
    session = click_button(session, "feedback")

    session
    |> assert_has("#donation-#{feedback.id}", "Free Sender")
    |> refute_has("#donation-#{paid.id}", "Paid Donor")
    |> refute_has("#donation-#{pending.id}", "Pending Donor")
  end

  test "tips filter ignores live free notes but inserts pending tips", %{
    conn: conn,
    pending: pending
  } do
    session =
      conn
      |> put_req_header("authorization", basic_auth_header())
      |> visit(~p"/admin")
      |> click_button("tips")

    session
    |> assert_has("#donation-#{pending.id}", "Pending Donor")

    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "Live Free Note",
        reaction: "good",
        message: "should not appear on tips"
      })

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, feedback}
    )

    Process.sleep(50)

    session
    |> refute_has("#donation-#{feedback.id}", "Live Free Note")
    |> assert_has("#donation-#{pending.id}", "Pending Donor")

    {:ok, new_pending} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-live-pending-tip",
        donor_name: "Live Pending Tip",
        reaction: "good",
        amount: 15_000
      })

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, new_pending}
    )

    Process.sleep(50)

    session
    |> assert_has("#donation-#{new_pending.id}", "Live Pending Tip")
    |> assert_has("#donation-#{pending.id}", "Pending Donor")
  end

  test "feedback filter inserts live free notes and ignores tips", %{conn: conn} do
    session =
      conn
      |> put_req_header("authorization", basic_auth_header())
      |> visit(~p"/admin")
      |> click_button("feedback")

    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "Live Feedback Note",
        reaction: "great",
        message: "should appear on feedback"
      })

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, feedback}
    )

    Process.sleep(50)

    session
    |> assert_has("#donation-#{feedback.id}", "Live Feedback Note")

    {:ok, tip} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-live-tip-on-feedback",
        donor_name: "Live Tip Ignored",
        reaction: "good",
        amount: 12_000
      })

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, tip}
    )

    Process.sleep(50)

    session
    |> refute_has("#donation-#{tip.id}", "Live Tip Ignored")
    |> assert_has("#donation-#{feedback.id}", "Live Feedback Note")
  end

  test "real-time payment updates tip cards on the tips filter", %{
    conn: conn,
    pending: pending,
    paid: paid
  } do
    session =
      conn
      |> put_req_header("authorization", basic_auth_header())
      |> visit(~p"/admin")

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

    session = click_button(session, "tips")

    session
    |> assert_has("#donation-#{new_pending.id}", "New Pending")
    |> assert_has("#donation-#{pending.id}", "Pending Donor")
    |> assert_has("#donation-#{paid.id}", "Paid Donor")

    {:ok, paid_new_pending, _} = Donations.mark_paid_with_change(new_pending)

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:paid",
      {:donation_paid, DonatexWeb.DonationPresenter.payload(paid_new_pending)}
    )

    Process.sleep(50)

    session
    |> assert_has("#donation-#{new_pending.id}", "New Pending")
    |> assert_has("#donation-#{paid.id}", "Paid Donor")

    session = click_button(session, "feedback")

    session
    |> refute_has("#donation-#{new_pending.id}", "New Pending")
    |> refute_has("#donation-#{paid.id}", "Paid Donor")
  end

  defp basic_auth_header do
    "Basic " <> Base.encode64("#{Config.admin_username()}:#{Config.admin_password()}")
  end
end
