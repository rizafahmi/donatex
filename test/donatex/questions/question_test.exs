defmodule Donatex.Questions.QuestionTest do
  use Donatex.DataCase, async: false

  alias Donatex.Questions.Question

  describe "create_changeset/2" do
    test "valid required body and optional name" do
      changeset =
        Question.create_changeset(%Question{}, %{
          "name" => "Riza",
          "body" => "Apa rencana stream?"
        })

      assert changeset.valid?
      assert get_field(changeset, :name) == "Riza"
      assert get_field(changeset, :body) == "Apa rencana stream?"
      assert get_field(changeset, :status) == "open"
    end

    test "blank name is normalized to nil, not persisted as Anonim" do
      for blank <- ["", "   ", nil] do
        changeset = Question.create_changeset(%Question{}, %{"name" => blank, "body" => "body"})
        assert changeset.valid?
        assert get_field(changeset, :name) == nil
      end
    end

    test "name is trimmed" do
      changeset =
        Question.create_changeset(%Question{}, %{"name" => "  Riza  ", "body" => "body"})

      assert get_field(changeset, :name) == "Riza"
    end

    test "body is required and trimmed" do
      changeset = Question.create_changeset(%Question{}, %{"name" => nil, "body" => "  "})
      refute changeset.valid?
      assert errors_on(changeset)[:body]
    end

    test "whitespace-only body is rejected" do
      changeset = Question.create_changeset(%Question{}, %{"body" => "\n\t  "})
      refute changeset.valid?
    end

    test "body max 500 characters boundary" do
      changeset = Question.create_changeset(%Question{}, %{"body" => String.duplicate("x", 500)})
      assert changeset.valid?

      changeset = Question.create_changeset(%Question{}, %{"body" => String.duplicate("x", 501)})
      refute changeset.valid?
    end

    test "name max 64 characters boundary" do
      changeset =
        Question.create_changeset(%Question{}, %{
          "name" => String.duplicate("x", 64),
          "body" => "body"
        })

      assert changeset.valid?

      changeset =
        Question.create_changeset(%Question{}, %{
          "name" => String.duplicate("x", 65),
          "body" => "body"
        })

      refute changeset.valid?
    end

    test "public creation cannot submit status or hidden_at" do
      changeset =
        Question.create_changeset(%Question{}, %{
          "body" => "body",
          "status" => "answered",
          "hidden_at" => ~U[2026-07-25 00:00:00Z]
        })

      assert get_field(changeset, :status) == "open"
      assert get_field(changeset, :hidden_at) == nil
    end
  end

  describe "status_changeset/2" do
    test "can transition status to answered" do
      changeset = Question.status_changeset(%Question{status: "open"}, %{"status" => "answered"})
      assert get_field(changeset, :status) == "answered"
      assert changeset.valid?
    end

    test "rejects unknown status" do
      changeset = Question.status_changeset(%Question{}, %{"status" => "closed"})
      refute changeset.valid?
    end

    test "does not allow body/name through the status changeset" do
      changeset =
        Question.status_changeset(%Question{body: "b"}, %{
          "status" => "answered",
          "body" => "overwritten"
        })

      assert get_field(changeset, :body) == "b"
    end
  end

  describe "hide_changeset/1 and restore_changeset/1" do
    test "hide_changeset sets hidden_at" do
      changeset = Question.hide_changeset(%Question{})
      assert changeset.valid?
      assert get_field(changeset, :hidden_at) != nil
    end

    test "restore_changeset clears hidden_at" do
      changeset = Question.restore_changeset(%Question{hidden_at: ~U[2026-07-25 00:00:00Z]})
      assert changeset.valid?
      assert get_field(changeset, :hidden_at) == nil
    end
  end
end
