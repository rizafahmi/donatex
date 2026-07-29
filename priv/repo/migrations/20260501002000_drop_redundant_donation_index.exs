defmodule Notable.Repo.Migrations.DropRedundantDonationIndex do
  use Ecto.Migration

  def change do
    drop index(:donations, [:status, :alerted, :inserted_at])
  end
end
