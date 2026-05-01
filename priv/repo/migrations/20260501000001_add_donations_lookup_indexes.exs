defmodule Donatex.Repo.Migrations.AddDonationsLookupIndexes do
  use Ecto.Migration

  def change do
    create index(:donations, [:status, :alerted, :inserted_at])
  end
end
