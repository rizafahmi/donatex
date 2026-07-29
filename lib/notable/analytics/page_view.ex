defmodule Notable.Analytics.PageView do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "page_views" do
    field :path, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(page_view, attrs) do
    page_view
    |> cast(attrs, [:path])
    |> validate_required([:path])
  end
end
