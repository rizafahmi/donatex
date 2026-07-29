defmodule Notable.Donations.Donation do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending paid sent)
  @reactions ~w(bad ok good great)

  schema "donations" do
    field :mayar_transaction_id, :string
    field :donor_name, :string
    field :reaction, :string
    field :amount, :integer
    field :message, :string
    field :status, :string, default: "pending"
    field :alerted, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(donation, attrs) do
    donation
    |> cast(attrs, [
      :mayar_transaction_id,
      :donor_name,
      :reaction,
      :amount,
      :message,
      :status,
      :alerted
    ])
    |> update_change(:mayar_transaction_id, &String.trim/1)
    |> update_change(:donor_name, &String.trim/1)
    |> update_change(:message, &String.trim/1)
    |> validate_required([:donor_name, :reaction])
    |> validate_payment_details()
    |> validate_length(:mayar_transaction_id, min: 1, max: 128)
    |> validate_length(:donor_name, min: 1, max: 64)
    |> validate_length(:message, max: 280)
    |> validate_inclusion(:reaction, @reactions)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
    |> unique_constraint(:mayar_transaction_id)
  end

  defp validate_payment_details(changeset) do
    case get_field(changeset, :status) do
      "sent" -> changeset
      _status -> validate_required(changeset, [:mayar_transaction_id, :amount])
    end
  end
end
