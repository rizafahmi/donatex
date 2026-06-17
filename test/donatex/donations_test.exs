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
                 amount: 10_000
               })

      assert {:error, changeset} =
               Donations.create_pending_donation(%{
                 mayar_transaction_id: "tx-duplicate",
                 donor_name: "Riza",
                 amount: 10_000
               })

      assert "has already been taken" in errors_on(changeset).mayar_transaction_id
    end
  end

  describe "mark_paid_by_mayar_transaction_id/1" do
    test "marks donation paid by mayar transaction id" do
      {:ok, donation} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-2",
          donor_name: "Donor",
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
  end

  describe "list_paid_unalerted_donations/0" do
    test "returns only paid and unalerted donations for overlay recovery" do
      {:ok, _pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-3",
          donor_name: "A",
          amount: 10_000
        })

      assert {:ok, %Donation{} = paid_unalerted} =
               Donations.mark_paid_by_mayar_transaction_id("tx-3")

      {:ok, _pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-4",
          donor_name: "B",
          amount: 10_000
        })

      {:ok, _pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-5",
          donor_name: "C",
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
                 amount: 50_000
               })

      assert {:error, :invalid_state} = Donations.mark_donation_alerted(donation)
    end

    test "is idempotent for already alerted donations" do
      {:ok, _pending} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-6c",
          donor_name: "D",
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

  describe "list_donations/0" do
    test "lists all donations for admin page ordered by newest first" do
      {:ok, first} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-7",
          donor_name: "E",
          amount: 15_000
        })

      {:ok, second} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-8",
          donor_name: "F",
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

      first_reloaded = Repo.get!(Donation, first.id)
      second_reloaded = Repo.get!(Donation, second.id)

      assert DateTime.compare(first_reloaded.inserted_at, older) == :eq
      assert DateTime.compare(second_reloaded.inserted_at, newer) == :eq

      result = Donations.list_donations()

      assert Enum.map(result, & &1.id) == [second.id, first.id]
    end
  end

  describe "get_donation_stats/0" do
    test "calculates paid and pending counts and paid sum" do
      {:ok, _pending1} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-stats-1",
          donor_name: "A",
          amount: 10_000
        })

      {:ok, _paid1} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-stats-2",
          donor_name: "B",
          amount: 20_000
        })

      {:ok, _paid2} =
        Donations.create_pending_donation(%{
          mayar_transaction_id: "tx-stats-3",
          donor_name: "C",
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
