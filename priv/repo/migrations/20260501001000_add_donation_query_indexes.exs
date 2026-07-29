defmodule Notable.Repo.Migrations.AddDonationQueryIndexes do
  use Ecto.Migration

  def change do
    create index(:donations, [:status, :alerted, :inserted_at, :id],
             name: :donations_recovery_queue_idx
           )
  end
end
