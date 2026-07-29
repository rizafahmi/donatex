defmodule Notable.Donations.DonationTest do
  use Notable.DataCase, async: false

  alias Notable.Donations.Donation

  test "changeset validates required fields" do
    changeset = Donation.changeset(%Donation{}, %{})

    refute changeset.valid?

    assert "can't be blank" in errors_on(changeset).mayar_transaction_id
    assert "can't be blank" in errors_on(changeset).donor_name
    assert "can't be blank" in errors_on(changeset).amount
  end

  test "changeset requires a reaction" do
    attrs = %{
      mayar_transaction_id: "tx_123",
      donor_name: "Riza",
      amount: 10_000
    }

    changeset = Donation.changeset(%Donation{}, attrs)

    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).reaction
  end

  test "changeset only accepts approved reactions" do
    attrs = %{
      mayar_transaction_id: "tx_123",
      donor_name: "Riza",
      reaction: "amazing",
      amount: 10_000
    }

    changeset = Donation.changeset(%Donation{}, attrs)

    refute changeset.valid?
    assert "is invalid" in errors_on(changeset).reaction
  end

  test "changeset only accepts allowed statuses" do
    attrs = %{
      mayar_transaction_id: "tx_123",
      donor_name: "Riza",
      reaction: "good",
      amount: 10_000,
      status: "nope"
    }

    changeset = Donation.changeset(%Donation{}, attrs)

    refute changeset.valid?
    assert "is invalid" in errors_on(changeset).status
  end

  test "changeset rejects non-integer amounts" do
    attrs = %{
      mayar_transaction_id: "tx_123",
      donor_name: "Riza",
      reaction: "good",
      amount: 12.5
    }

    changeset = Donation.changeset(%Donation{}, attrs)

    refute changeset.valid?
    assert "is invalid" in errors_on(changeset).amount
  end

  test "changeset defaults status to pending" do
    attrs = %{
      mayar_transaction_id: "tx_123",
      donor_name: "Riza",
      reaction: "good",
      amount: 10_000
    }

    changeset = Donation.changeset(%Donation{}, attrs)

    assert changeset.valid?
    assert get_field(changeset, :status) == "pending"
    assert is_integer(get_field(changeset, :amount))
  end
end
