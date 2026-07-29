defmodule Notable.Questions.QuestionVoteTest do
  use Notable.DataCase, async: false

  alias Notable.Questions.QuestionVote

  test "vote changeset requires question_id and visitor_hash" do
    changeset = QuestionVote.changeset(%QuestionVote{}, %{})
    refute changeset.valid?
    assert errors_on(changeset)[:question_id]
    assert errors_on(changeset)[:visitor_hash]
  end

  test "vote changeset accepts a question_id and visitor_hash" do
    changeset =
      QuestionVote.changeset(%QuestionVote{}, %{
        "question_id" => Ecto.UUID.generate(),
        "visitor_hash" => String.duplicate("a", 64)
      })

    assert changeset.valid?
  end

  test "vote changeset carries a unique_constraint matching the migration index" do
    changeset = QuestionVote.changeset(%QuestionVote{}, %{})
    constraints = changeset.constraints
    assert Enum.any?(constraints, &(&1.type == :unique))
  end
end
