defmodule Donatex.Repo.Migrations.AddReactionToDonations do
  use Ecto.Migration

  def change do
    alter table(:donations) do
      add :reaction, :string
    end
  end
end
