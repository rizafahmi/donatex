defmodule Notable.PageViewsMigrationTest do
  use Notable.DataCase, async: false

  alias Ecto.Adapters.SQL
  alias Notable.Repo

  test "page_views has indexes for path and inserted_at query paths" do
    %{rows: index_rows} = SQL.query!(Repo, "PRAGMA index_list(page_views)", [])

    index_names =
      index_rows
      |> Enum.map(fn [_seq, name, _unique | _rest] -> name end)
      |> MapSet.new()

    path_index =
      Enum.find(index_names, fn name ->
        String.contains?(name, "path")
      end)

    inserted_at_index =
      Enum.find(index_names, fn name ->
        String.contains?(name, "inserted_at")
      end)

    assert is_binary(path_index)
    assert is_binary(inserted_at_index)
    assert index_columns(path_index) == ["path"]
    assert index_columns(inserted_at_index) == ["inserted_at"]
  end

  defp index_columns(index_name) do
    %{rows: rows} = SQL.query!(Repo, "PRAGMA index_info(#{index_name})", [])

    rows
    |> Enum.sort_by(fn [seqno, _cid, _name] -> seqno end)
    |> Enum.map(fn [_seqno, _cid, name] -> name end)
  end
end
