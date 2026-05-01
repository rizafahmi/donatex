defmodule Donatex.Donations.Donation do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending paid)

  schema "donations" do
    field :mayar_transaction_id, :string
    field :donor_name, :string
    field :amount, :integer
    field :message, :string
    field :status, :string, default: "pending"
    field :alerted, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(donation, attrs) do
    donation
    |> cast(attrs, [:mayar_transaction_id, :donor_name, :amount, :message, :status, :alerted])
    |> validate_required([:mayar_transaction_id, :donor_name, :amount])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
  end
end
