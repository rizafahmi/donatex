defmodule Donatex.Repo.Migrations.CreatePageViews do
  use Ecto.Migration

  def change do
    create table(:page_views, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :path, :string, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
