defmodule Donatex.DonationsMigrationTest do
  use Donatex.DataCase, async: true
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

    assert by_name["mayar_transaction_id"].notnull == 1
    assert by_name["donor_name"].notnull == 1
    assert by_name["amount"].notnull == 1
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
  end
end
