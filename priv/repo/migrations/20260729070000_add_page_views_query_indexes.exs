defmodule Donatex.Repo.Migrations.AddPageViewsQueryIndexes do
  use Ecto.Migration

  def change do
    # Analytics records path on every view; support path-filtered counts/listings.
    create index(:page_views, [:path])
    # Support time-ordered / time-window analytics listings as volume grows.
    create index(:page_views, [:inserted_at])
  end
end
