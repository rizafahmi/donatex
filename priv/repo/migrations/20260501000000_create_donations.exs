defmodule Notable.Repo.Migrations.CreateDonations do
  use Ecto.Migration

  def change do
    create table(:donations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :mayar_transaction_id, :string, null: false
      add :donor_name, :string, null: false
      add :amount, :integer, null: false
      add :message, :text
      add :status, :string, null: false, default: "pending"
      add :alerted, :boolean, null: false, default: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:donations, [:mayar_transaction_id])
  end
end
