defmodule Notable.AnalyticsTest do
  use Notable.DataCase, async: false

  alias Notable.Analytics
  alias Notable.Analytics.PageView
  alias Notable.Donations
  alias Notable.Repo

  describe "track_page_view/1" do
    test "asynchronously records a page view and broadcasts the event" do
      # Subscribe to the analytics channel
      Phoenix.PubSub.subscribe(Notable.PubSub, "analytics:page_view")

      # Track the page view
      assert {:ok, _pid} = Analytics.track_page_view("/")

      # Await the broadcast to ensure the task has finished executing
      assert_receive {:page_view_recorded, "/"}

      # Verify the record exists in the database
      assert [page_view] = Repo.all(PageView)
      assert page_view.path == "/"
    end
  end

  describe "get_funnel_stats/0" do
    test "accurately counts page views, feedback, and paid tips" do
      # Pre-seed some page views
      # Note: We can insert directly to bypass async task in the stats test
      %PageView{path: "/"} |> Repo.insert!()
      %PageView{path: "/"} |> Repo.insert!()
      %PageView{path: "/"} |> Repo.insert!()

      # Pre-seed some feedback notes (status = sent)
      {:ok, _feedback1} =
        Donations.create_feedback(%{
          donor_name: "User A",
          reaction: "good",
          message: "Great stream!"
        })

      # Pre-seed some paid tips (status = paid)
      {:ok, tip} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-test-funnel-1",
          donor_name: "Donor B",
          reaction: "great",
          amount: 50_000,
          message: "Keep it up!"
        })

      {:ok, _paid_tip, _} = Donations.mark_paid_with_change(tip)

      # Pre-seed a pending tip (should NOT count as paid or feedback)
      {:ok, _pending_tip} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-test-funnel-2",
          donor_name: "Donor C",
          reaction: "ok",
          amount: 10_000
        })

      # Fetch and verify funnel stats
      stats = Analytics.get_funnel_stats()

      assert stats.views == 3
      assert stats.feedback == 1
      assert stats.paid == 1
    end

    test "handles zero values correctly when no records exist" do
      stats = Analytics.get_funnel_stats()

      assert stats.views == 0
      assert stats.feedback == 0
      assert stats.paid == 0
    end
  end
end
