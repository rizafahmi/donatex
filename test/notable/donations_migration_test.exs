defmodule Notable.DonationsMigrationTest do
  use Notable.DataCase, async: false
  alias Ecto.Adapters.SQL

  test "donations table exists with expected columns, defaults, and unique index" do
    %{rows: rows} = SQL.query!(Repo, "PRAGMA table_info(donations)", [])

    column_names =
      rows
      |> Enum.map(fn [_cid, name, _type, _notnull, _dflt_value, _pk] -> name end)
      |> MapSet.new()

    assert column_names ==
             MapSet.new([
               "id",
               "mayar_transaction_id",
               "donor_name",
               "reaction",
               "amount",
               "message",
               "status",
               "alerted",
               "inserted_at",
               "updated_at"
             ])

    by_name =
      Map.new(rows, fn [_cid, name, _type, notnull, dflt_value, _pk] ->
        {name, %{notnull: notnull, dflt_value: dflt_value}}
      end)

    # Payment details are nullable so free feedback Notes can omit them.
    assert by_name["mayar_transaction_id"].notnull == 0
    assert by_name["donor_name"].notnull == 1
    assert by_name["reaction"].notnull == 0
    assert by_name["amount"].notnull == 0
    assert by_name["status"].notnull == 1
    assert by_name["alerted"].notnull == 1

    assert to_string(by_name["status"].dflt_value) =~ "pending"
    assert to_string(by_name["alerted"].dflt_value) in ["0", "false", "FALSE"]

    %{rows: index_rows} = SQL.query!(Repo, "PRAGMA index_list(donations)", [])

    mayar_index =
      Enum.find(index_rows, fn [_seq, name, unique | _rest] ->
        unique == 1 and String.contains?(name, "mayar_transaction_id")
      end)

    assert is_list(mayar_index)

    [_seq, index_name, _unique | _rest] = mayar_index

    %{rows: index_info_rows} = SQL.query!(Repo, "PRAGMA index_info(#{index_name})", [])

    assert Enum.any?(index_info_rows, fn [_seqno, _cid, name] ->
             name == "mayar_transaction_id"
           end)

    assert index_columns("donations_recovery_queue_idx") == [
             "status",
             "alerted",
             "inserted_at",
             "id"
           ]

    assert index_columns("donations_order_idx") == ["inserted_at", "id"]
  end

  defp index_columns(index_name) do
    %{rows: rows} = SQL.query!(Repo, "PRAGMA index_info(#{index_name})", [])

    rows
    |> Enum.sort_by(fn [seqno, _cid, _name] -> seqno end)
    |> Enum.map(fn [_seqno, _cid, name] -> name end)
  end
end
