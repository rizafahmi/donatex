defmodule Notable.Repo.Migrations.AddDonationsOrderIndex do
  use Ecto.Migration

  def change do
    create index(:donations, [:inserted_at, :id], name: :donations_order_idx)
  end
end
