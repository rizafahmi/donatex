defmodule DonatexWeb.AdminAnalyticsTest do
  use DonatexWeb.ConnCase, async: false

  alias Donatex.Analytics
  alias Donatex.Config
  alias Donatex.Donations
  alias Donatex.Repo

  import PhoenixTest

  setup do
    # Ensure tables are clean before running analytics tests
    Repo.delete_all(Donatex.Analytics.PageView)
    Repo.delete_all(Donatex.Donations.Donation)
    :ok
  end

  test "admin panel renders conversion funnel and updates in real-time", %{conn: conn} do
    # 1. Access admin page with initial clean state
    session =
      conn
      |> put_req_header("authorization", basic_auth_header())
      |> visit(~p"/admin")

    # Initial state should show 0 views, 0 feedback, 0 tips
    session
    |> assert_has("h2", "Conversion Funnel")
    |> assert_has("div", "0 loads")
    |> assert_has("div", "0 notes")
    |> assert_has("div", "0 tips")
    # Rates should show 0.0%
    |> assert_has("span", "0.0%")

    # 2. Simulate raw page load on /
    conn
    |> visit(~p"/")

    # Wait for the async task to insert and broadcast
    Process.sleep(50)

    # Re-fetch the page view count directly to verify it was stored
    assert %{views: 1} = Analytics.get_funnel_stats()

    # The admin panel should update dynamically due to PubSub subscription
    session
    |> assert_has("div", "1 loads")

    # 3. Simulate another page view via track_page_view (inserts and broadcasts)
    Analytics.track_page_view("/")

    Process.sleep(50)

    session
    |> assert_has("div", "2 loads")

    # 4. Create feedback (status = sent) and broadcast
    {:ok, feedback} =
      Donations.create_feedback(%{
        donor_name: "Feedbacker",
        reaction: "good",
        message: "Nice stream!"
      })

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:created",
      {:donation_created, feedback}
    )

    Process.sleep(50)

    # 2 views, 1 feedback note -> 50.0% conversion
    session
    |> assert_has("div", "1 notes")
    |> assert_has("span", "50.0%")

    # 5. Create a paid tip and broadcast
    {:ok, tip} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-analytics-test",
        donor_name: "Donor",
        reaction: "great",
        amount: 15_000,
        message: "Super tip!"
      })

    {:ok, paid_tip, _} = Donations.mark_paid_with_change(tip)

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:paid",
      {:donation_paid, DonatexWeb.DonationPresenter.payload(paid_tip)}
    )

    Process.sleep(50)

    # 2 views, 1 paid tip -> 50.0% conversion
    session
    |> assert_has("div", "1 tips")
    |> assert_has("span", "50.0%")
  end

  test "admin panel handles capping conversion rates when views < feedback + tips", %{conn: conn} do
    # Pre-seed 1 view but 2 feedback notes (e.g. historical data)
    %Donatex.Analytics.PageView{path: "/"} |> Repo.insert!()

    {:ok, _} = Donations.create_feedback(%{donor_name: "A", reaction: "ok"})
    {:ok, _} = Donations.create_feedback(%{donor_name: "B", reaction: "ok"})

    session =
      conn
      |> put_req_header("authorization", basic_auth_header())
      |> visit(~p"/admin")

    # 1 view, 2 feedback -> capped at 100.0% and warning shown
    session
    |> assert_has("span", "100.0%")
    |> assert_has("span", "Stats adjusted for historical notes/tips")
  end

  defp basic_auth_header do
    "Basic " <> Base.encode64("#{Config.admin_username()}:#{Config.admin_password()}")
  end
end
