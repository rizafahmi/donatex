defmodule Donatex.DonationsTest do
  use Donatex.DataCase, async: false

  import Ecto.Query, only: [from: 2]

  alias Donatex.Donations
  alias Donatex.Donations.Donation
  alias Donatex.Repo

  describe "create_pending_donation/1" do
    test "creates a pending donation at QR generation time" do
      attrs = %{
        mayar_transaction_id: "tx-1",
        donor_name: "Riza",
        reaction: "great",
        amount: 10_000,
        message: "semangat"
      }

      assert {:ok, %Donation{} = donation} = Donations.create_pending_donation(attrs)
      assert donation.mayar_transaction_id == "tx-1"
      assert donation.donor_name == "Riza"
      assert donation.amount == 10_000
      assert donation.message == "semangat"
      assert donation.status == "pending"
      refute donation.alerted
    end

    test "rejects duplicate mayar_transaction_id values" do
      assert {:ok, %Donation{}} =
               Donations.create_pending_donation(%{
                 mayar_transaction_id: "tx-duplicate",
                 donor_name: "Riza",
                 reaction: "good",
                 amount: 10_000
               })

      assert {:error, changeset} =
               Donations.create_pending_donation(%{
                 mayar_transaction_id: "tx-duplicate",
                 donor_name: "Riza",
                 reaction: "good",
                 amount: 10_000
               })

      assert "has already been taken" in errors_on(changeset).mayar_transaction_id
    end
  end

  describe "create_feedback/1" do
    test "creates an alerted sent note without payment details" do
      assert {:ok, %Donation{} = feedback} =
               Donations.create_feedback(%{
                 donor_name: "Riza",
                 reaction: "great",
                 message: "Stream-nya seru"
               })

      assert feedback.donor_name == "Riza"
      assert feedback.reaction == "great"
      assert feedback.message == "Stream-nya seru"
      assert feedback.status == "sent"
      assert feedback.alerted
      assert is_nil(feedback.mayar_transaction_id)
      assert is_nil(feedback.amount)
    end
  end

  describe "claim_pending_by_amount_as_paid/3" do
    test "claims a unique pending tip by amount and remaps transaction id" do
      {:ok, donation} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-amount-original",
          donor_name: "Maya",
          reaction: "great",
          amount: 15_000
        })

      assert {:ok, %Donation{} = paid, true} =
               Donations.claim_pending_by_amount_as_paid(15_000, "tx-amount-confirmation", "Maya")

      assert paid.id == donation.id
      assert paid.status == "paid"
      assert paid.mayar_transaction_id == "tx-amount-confirmation"

      assert %Donation{status: "paid", mayar_transaction_id: "tx-amount-confirmation"} =
               Repo.get!(Donation, donation.id)
    end

    test "fails closed when multiple pending tips share the same amount" do
      {:ok, first} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-ambiguous-1",
          donor_name: "A",
          reaction: "good",
          amount: 15_000
        })

      {:ok, second} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-ambiguous-2",
          donor_name: "B",
          reaction: "good",
          amount: 15_000
        })

      assert {:error, :ambiguous} =
               Donations.claim_pending_by_amount_as_paid(15_000, "tx-ambiguous-confirm")

      assert %Donation{status: "pending", mayar_transaction_id: "tx-ambiguous-1"} =
               Repo.get!(Donation, first.id)

      assert %Donation{status: "pending", mayar_transaction_id: "tx-ambiguous-2"} =
               Repo.get!(Donation, second.id)
    end

    test "disambiguates same-amount tips by donor_name" do
      {:ok, _other} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-disambig-other",
          donor_name: "Other",
          reaction: "good",
          amount: 15_000
        })

      {:ok, target} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-disambig-target",
          donor_name: "Maya",
          reaction: "great",
          amount: 15_000
        })

      assert {:ok, %Donation{} = paid, true} =
               Donations.claim_pending_by_amount_as_paid(15_000, "tx-disambig-confirm", "Maya")

      assert paid.id == target.id
      assert paid.mayar_transaction_id == "tx-disambig-confirm"

      assert %Donation{status: "pending", mayar_transaction_id: "tx-disambig-other"} =
               Repo.get_by!(Donation, mayar_transaction_id: "tx-disambig-other")
    end

    test "returns not_found for orphan payments with no pending match" do
      assert {:error, :not_found} =
               Donations.claim_pending_by_amount_as_paid(99_000, "tx-orphan-confirm", "Ghost")
    end

    test "returns transaction_id_taken when remap hits an existing id" do
      {:ok, _taken} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-already-taken",
          donor_name: "Keeper",
          reaction: "good",
          amount: 20_000
        })

      {:ok, candidate} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-candidate-original",
          donor_name: "Maya",
          reaction: "great",
          amount: 15_000
        })

      assert {:error, :transaction_id_taken} =
               Donations.claim_pending_by_amount_as_paid(15_000, "tx-already-taken", "Maya")

      assert %Donation{status: "pending", mayar_transaction_id: "tx-candidate-original"} =
               Repo.get!(Donation, candidate.id)
    end

    test "is idempotent after a successful amount-fallback claim" do
      {:ok, donation} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-idem-original",
          donor_name: "Maya",
          reaction: "great",
          amount: 15_000
        })

      assert {:ok, %Donation{}, true} =
               Donations.claim_pending_by_amount_as_paid(15_000, "tx-idem-confirm", "Maya")

      assert {:ok, %Donation{} = again, false} =
               Donations.claim_pending_by_amount_as_paid(15_000, "tx-idem-confirm", "Maya")

      assert again.id == donation.id
      assert again.status == "paid"
    end
  end

  describe "mark_paid_by_mayar_transaction_id/1" do
    test "marks donation paid by mayar transaction id" do
      {:ok, donation} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-2",
          donor_name: "Donor",
          reaction: "good",
          amount: 25_000
        })

      assert donation.status == "pending"

      assert {:ok, %Donation{} = updated} =
               Donations.mark_paid_by_mayar_transaction_id("tx-2")

      assert updated.id == donation.id
      assert updated.status == "paid"
    end

    test "is idempotent for already paid donations" do
      {:ok, donation} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-2b",
          donor_name: "Donor",
          reaction: "good",
          amount: 25_000
        })

      assert {:ok, %Donation{} = updated} =
               Donations.mark_paid_by_mayar_transaction_id("tx-2b")

      assert updated.id == donation.id
      assert updated.status == "paid"

      assert {:ok, %Donation{} = second} =
               Donations.mark_paid_by_mayar_transaction_id("tx-2b")

      assert second.id == donation.id
      assert second.status == "paid"
    end

    test "returns not_found when transaction id does not exist" do
      assert {:error, :not_found} = Donations.mark_paid_by_mayar_transaction_id("tx-missing")
    end

    test "claims paid at most once under concurrent mark_paid calls" do
      {:ok, donation} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-concurrent-claim",
          donor_name: "Donor",
          reaction: "good",
          amount: 25_000
        })

      results =
        1..12
        |> Enum.map(fn _ ->
          Task.async(fn -> Donations.mark_paid_with_change(donation) end)
        end)
        |> Enum.map(&Task.await(&1, 5_000))

      winners = for {:ok, %Donation{status: "paid"}, true} <- results, do: true
      losers = for {:ok, %Donation{status: "paid"}, false} <- results, do: true

      assert length(winners) == 1
      assert length(losers) == 11
      assert %Donation{status: "paid"} = Repo.get!(Donation, donation.id)
    end
  end

  describe "list_paid_unalerted_donations/0" do
    test "returns only paid and unalerted donations for overlay recovery" do
      {:ok, _pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-3",
          donor_name: "A",
          reaction: "bad",
          amount: 10_000
        })

      assert {:ok, %Donation{} = paid_unalerted} =
               Donations.mark_paid_by_mayar_transaction_id("tx-3")

      {:ok, _pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-4",
          donor_name: "B",
          reaction: "ok",
          amount: 10_000
        })

      {:ok, _pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-5",
          donor_name: "C",
          reaction: "great",
          amount: 10_000
        })

      assert {:ok, %Donation{} = paid} = Donations.mark_paid_by_mayar_transaction_id("tx-5")
      assert {:ok, %Donation{} = _paid_alerted} = Donations.mark_donation_alerted(paid)

      result = Donations.list_paid_unalerted_donations()

      assert Enum.map(result, & &1.id) == [paid_unalerted.id]
    end
  end

  describe "mark_donation_alerted/1" do
    test "marks paid donation as alerted" do
      {:ok, _pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-6",
          donor_name: "D",
          reaction: "good",
          amount: 50_000
        })

      assert {:ok, %Donation{} = donation} = Donations.mark_paid_by_mayar_transaction_id("tx-6")
      assert {:ok, %Donation{} = updated} = Donations.mark_donation_alerted(donation)
      assert updated.id == donation.id
      assert updated.alerted
      assert updated.status == "paid"
    end

    test "rejects alerting a pending donation" do
      assert {:ok, %Donation{} = donation} =
               Donations.create_pending_donation(%{
                 mayar_transaction_id: "tx-6b",
                 donor_name: "D",
                 reaction: "good",
                 amount: 50_000
               })

      assert {:error, :invalid_state} = Donations.mark_donation_alerted(donation)
    end

    test "is idempotent for already alerted donations" do
      {:ok, _pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-6c",
          donor_name: "D",
          reaction: "good",
          amount: 50_000
        })

      assert {:ok, %Donation{} = donation} = Donations.mark_paid_by_mayar_transaction_id("tx-6c")
      assert {:ok, %Donation{} = alerted} = Donations.mark_donation_alerted(donation)
      assert alerted.alerted

      assert {:ok, %Donation{} = second} = Donations.mark_donation_alerted(alerted)
      assert second.id == alerted.id
      assert second.alerted
    end
  end

  describe "mark_donation_alerted_by_id/1" do
    test "marks paid donation as alerted" do
      {:ok, _pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-alerted-by-id-1",
          donor_name: "D",
          reaction: "good",
          amount: 50_000
        })

      assert {:ok, %Donation{} = donation} =
               Donations.mark_paid_by_mayar_transaction_id("tx-alerted-by-id-1")

      assert {:ok, %Donation{} = updated} = Donations.mark_donation_alerted_by_id(donation.id)
      assert updated.alerted
      assert updated.status == "paid"
    end

    test "returns not_found for unknown ids" do
      assert {:error, :not_found} = Donations.mark_donation_alerted_by_id(Ecto.UUID.generate())
    end
  end

  describe "list_donations/1" do
    test "defaults to paid donations" do
      {:ok, _pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-list-pending-1",
          donor_name: "Pending Donor",
          reaction: "ok",
          amount: 10_000
        })

      {:ok, paid} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-list-paid-1",
          donor_name: "Paid Donor",
          reaction: "great",
          amount: 20_000
        })

      {:ok, paid, _} = Donations.mark_paid_with_change(paid)

      result = Donations.list_donations()
      assert Enum.map(result, & &1.id) == [paid.id]
    end

    test "lists all, paid, or pending donations based on filter" do
      {:ok, pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-list-pending-2",
          donor_name: "Pending Donor",
          reaction: "ok",
          amount: 10_000
        })

      {:ok, paid} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-list-paid-2",
          donor_name: "Paid Donor",
          reaction: "great",
          amount: 20_000
        })

      {:ok, paid, _} = Donations.mark_paid_with_change(paid)

      # Test atom filters
      assert Enum.map(Donations.list_donations(:all), & &1.id) |> Enum.sort() ==
               Enum.sort([pending.id, paid.id])

      assert Enum.map(Donations.list_donations(:paid), & &1.id) == [paid.id]
      assert Enum.map(Donations.list_donations(:pending), & &1.id) == [pending.id]

      # Test string filters
      assert Enum.map(Donations.list_donations("all"), & &1.id) |> Enum.sort() ==
               Enum.sort([pending.id, paid.id])

      assert Enum.map(Donations.list_donations("paid"), & &1.id) == [paid.id]
      assert Enum.map(Donations.list_donations("pending"), & &1.id) == [pending.id]
    end

    test "lists tips as rows with an amount, excluding feedback" do
      {:ok, pending_tip} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-list-tips-pending",
          donor_name: "Pending Tipper",
          reaction: "ok",
          amount: 10_000
        })

      {:ok, paid_tip} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-list-tips-paid",
          donor_name: "Paid Tipper",
          reaction: "great",
          amount: 20_000
        })

      {:ok, paid_tip, _} = Donations.mark_paid_with_change(paid_tip)

      {:ok, feedback} =
        Donations.create_feedback(%{
          donor_name: "Free Sender",
          reaction: "good",
          message: "no tip"
        })

      tip_ids = Enum.map(Donations.list_donations(:tips), & &1.id)
      assert Enum.sort(tip_ids) == Enum.sort([pending_tip.id, paid_tip.id])
      refute feedback.id in tip_ids

      assert Enum.map(Donations.list_donations("tips"), & &1.id) |> Enum.sort() ==
               Enum.sort([pending_tip.id, paid_tip.id])
    end

    test "lists feedback as sent notes, excluding tips" do
      {:ok, pending_tip} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-list-feedback-pending",
          donor_name: "Pending Tipper",
          reaction: "ok",
          amount: 10_000
        })

      {:ok, paid_tip} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-list-feedback-paid",
          donor_name: "Paid Tipper",
          reaction: "great",
          amount: 20_000
        })

      {:ok, paid_tip, _} = Donations.mark_paid_with_change(paid_tip)

      {:ok, feedback} =
        Donations.create_feedback(%{
          donor_name: "Free Sender",
          reaction: "good",
          message: "no tip"
        })

      feedback_ids = Enum.map(Donations.list_donations(:feedback), & &1.id)
      assert feedback_ids == [feedback.id]
      refute pending_tip.id in feedback_ids
      refute paid_tip.id in feedback_ids

      assert Enum.map(Donations.list_donations("feedback"), & &1.id) == [feedback.id]
    end

    test "lists all donations ordered by newest first" do
      {:ok, first} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-7",
          donor_name: "E",
          reaction: "good",
          amount: 15_000
        })

      {:ok, second} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-8",
          donor_name: "F",
          reaction: "great",
          amount: 20_000
        })

      older = ~U[2026-01-01 00:00:00Z]
      newer = ~U[2026-01-02 00:00:00Z]

      Repo.update_all(from(d in Donation, where: d.id == ^first.id),
        set: [inserted_at: older, updated_at: older]
      )

      Repo.update_all(from(d in Donation, where: d.id == ^second.id),
        set: [inserted_at: newer, updated_at: newer]
      )

      result = Donations.list_donations(:all)

      assert Enum.map(result, & &1.id) == [second.id, first.id]
    end
  end

  describe "get_donation_stats/0" do
    test "calculates paid and pending counts and paid sum" do
      {:ok, _pending1} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-stats-1",
          donor_name: "A",
          reaction: "bad",
          amount: 10_000
        })

      {:ok, _paid1} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-stats-2",
          donor_name: "B",
          reaction: "ok",
          amount: 20_000
        })

      {:ok, _paid2} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-stats-3",
          donor_name: "C",
          reaction: "great",
          amount: 30_000
        })

      {:ok, _} = Donations.mark_paid_by_mayar_transaction_id("tx-stats-2")
      {:ok, _} = Donations.mark_paid_by_mayar_transaction_id("tx-stats-3")

      stats = Donations.get_donation_stats()
      assert stats.paid_count == 2
      assert stats.paid_sum == 50_000
      assert stats.pending_count == 1
    end
  end
end

defmodule Donatex.DonationsConcurrencyTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Donatex.Donations
  alias Donatex.Donations.Donation
  alias Donatex.Repo
  alias Ecto.Adapters.SQL.Sandbox

  test "concurrent donor-disambiguated fallback claims both complete" do
    :ok = Sandbox.checkout(Repo, sandbox: false)

    amount = 91_337
    suffix = System.unique_integer([:positive])
    first_name = "Concurrent First #{suffix}"
    second_name = "Concurrent Second #{suffix}"

    {:ok, first} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-concurrent-first-original-#{suffix}",
        donor_name: first_name,
        reaction: "good",
        amount: amount
      })

    {:ok, second} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-concurrent-second-original-#{suffix}",
        donor_name: second_name,
        reaction: "great",
        amount: amount
      })

    donation_ids = [first.id, second.id]

    on_exit(fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)
      Repo.delete_all(from d in Donation, where: d.id in ^donation_ids)
    end)

    parent = self()

    first_task =
      Task.async(fn ->
        :ok = Sandbox.checkout(Repo, sandbox: false)

        Repo.transaction(
          fn ->
            result =
              Donations.claim_pending_by_amount_as_paid(
                amount,
                "tx-concurrent-first-confirm-#{suffix}",
                first_name
              )

            send(parent, {:first_claimed, result})
            receive do: (:release_first_claim -> result)
          end,
          mode: :immediate
        )
      end)

    assert_receive {:first_claimed, {:ok, %Donation{id: first_id}, true}}, 1_000
    assert first_id == first.id

    second_task =
      Task.async(fn ->
        :ok = Sandbox.checkout(Repo, sandbox: false)

        Donations.claim_pending_by_amount_as_paid(
          amount,
          "tx-concurrent-second-confirm-#{suffix}",
          second_name
        )
      end)

    Process.sleep(50)
    send(first_task.pid, :release_first_claim)

    assert {:ok, {:ok, %Donation{id: ^first_id}, true}} = Task.await(first_task, 2_000)
    assert {:ok, %Donation{id: second_id}, true} = Task.await(second_task, 2_000)
    assert second_id == second.id

    assert %Donation{status: "paid"} = Repo.get!(Donation, first.id)
    assert %Donation{status: "paid"} = Repo.get!(Donation, second.id)
  end
end
