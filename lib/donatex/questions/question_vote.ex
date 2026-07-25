defmodule Donatex.Questions.QuestionVote do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "question_votes" do
    belongs_to :question, Donatex.Questions.Question

    field :visitor_hash, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for a vote. `visitor_hash` is the SHA-256 hex of the opaque
  session visitor id, produced by the Questions context — never the raw
  session value.
  """
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:question_id, :visitor_hash])
    |> validate_required([:question_id, :visitor_hash])
    |> unique_constraint([:question_id, :visitor_hash],
      name: :question_votes_question_id_visitor_hash_index
    )
  end
end
