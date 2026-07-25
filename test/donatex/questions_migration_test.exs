defmodule Donatex.QuestionsMigrationTest do
  use Donatex.DataCase, async: false

  alias Donatex.Repo
  alias Ecto.Adapters.SQL

  test "questions table has expected columns, defaults, and nullability" do
    %{rows: rows} = SQL.query!(Repo, "PRAGMA table_info(questions)", [])

    column_names =
      rows
      |> Enum.map(fn [_cid, name, _type, _notnull, _default, _pk] -> name end)
      |> MapSet.new()

    assert column_names ==
             MapSet.new([
               "id",
               "name",
               "body",
               "status",
               "hidden_at",
               "inserted_at",
               "updated_at"
             ])

    by_name =
      Map.new(rows, fn [_cid, name, _type, notnull, dflt_value, _pk] ->
        {name, %{notnull: notnull, dflt_value: dflt_value}}
      end)

    # Name is optional; blank names are normalized to nil in the schema.
    assert by_name["name"].notnull == 0
    # Body is required.
    assert by_name["body"].notnull == 1
    # Status defaults to "open" and is required.
    assert by_name["status"].notnull == 1
    assert to_string(by_name["status"].dflt_value) =~ "open"
    # Hidden is an independent moderation state, nullable.
    assert by_name["hidden_at"].notnull == 0
    assert by_name["hidden_at"].dflt_value == nil
  end

  test "question_votes table has expected columns, nullability, and foreign key" do
    %{rows: rows} = SQL.query!(Repo, "PRAGMA table_info(question_votes)", [])

    column_names =
      rows
      |> Enum.map(fn [_cid, name, _type, _notnull, _default, _pk] -> name end)
      |> MapSet.new()

    assert column_names ==
             MapSet.new([
               "id",
               "question_id",
               "visitor_hash",
               "inserted_at",
               "updated_at"
             ])

    by_name =
      Map.new(rows, fn [_cid, name, _type, notnull, _dflt_value, _pk] ->
        {name, %{notnull: notnull}}
      end)

    assert by_name["question_id"].notnull == 1
    assert by_name["visitor_hash"].notnull == 1

    %{rows: fk_rows} = SQL.query!(Repo, "PRAGMA foreign_key_list(question_votes)", [])

    fk =
      Enum.find(fk_rows, fn [_id, _seq, table, _from, _to, _on_update, _on_delete, _match] ->
        table == "questions"
      end)

    assert is_list(fk)

    [_id, _seq, "questions", "question_id", "id", _on_update, on_delete, _match] = fk
    assert on_delete == "CASCADE"
  end

  test "deleting a question cascades to its votes" do
    %{rows: [[_cid, "id" | _] | _]} = SQL.query!(Repo, "PRAGMA table_info(questions)", [])

    SQL.query!(Repo, "PRAGMA foreign_keys = ON", [])

    SQL.query!(
      Repo,
      "INSERT INTO questions (id, body, status, inserted_at, updated_at) VALUES (?, 'open q', 'open', '2026-07-25 00:00:00', '2026-07-25 00:00:00')",
      ["q-1"]
    )

    SQL.query!(
      Repo,
      "INSERT INTO question_votes (id, question_id, visitor_hash, inserted_at, updated_at) VALUES (?, ?, 'hash-a', '2026-07-25 00:00:00', '2026-07-25 00:00:00')",
      ["v-1", "q-1"]
    )

    SQL.query!(Repo, "DELETE FROM questions WHERE id = ?", ["q-1"])

    %{rows: vote_rows} =
      SQL.query!(Repo, "SELECT id FROM question_votes WHERE question_id = ?", ["q-1"])

    assert vote_rows == []
  end

  test "question_votes has a unique index on question_id and visitor_hash" do
    %{rows: index_rows} = SQL.query!(Repo, "PRAGMA index_list(question_votes)", [])

    unique_index =
      Enum.find(index_rows, fn [_seq, name, unique | _rest] ->
        unique == 1 and String.contains?(name, "question_votes")
      end)

    assert is_list(unique_index)

    [_seq, index_name, _unique | _rest] = unique_index
    assert index_columns(index_name) == ["question_id", "visitor_hash"]
  end

  test "questions has an index supporting date/order queries" do
    %{rows: index_rows} = SQL.query!(Repo, "PRAGMA index_list(questions)", [])

    assert Enum.any?(index_rows, fn [_seq, name, _unique | _rest] ->
             String.contains?(name, "questions")
           end)
  end

  defp index_columns(index_name) do
    %{rows: rows} = SQL.query!(Repo, "PRAGMA index_info(#{index_name})", [])

    rows
    |> Enum.sort_by(fn [seqno, _cid, _name] -> seqno end)
    |> Enum.map(fn [_seqno, _cid, name] -> name end)
  end
end
