defmodule Donatex.RepoSqlitePragmasTest do
  use Donatex.DataCase, async: false

  alias Ecto.Adapters.SQL

  test "Repo connections use WAL journal mode and busy_timeout 5000" do
    repo_config = Donatex.Repo.config()

    assert repo_config[:journal_mode] == :wal
    assert repo_config[:busy_timeout] == 5_000

    %{rows: [[journal_mode]]} = SQL.query!(Repo, "PRAGMA journal_mode", [])
    assert journal_mode == "wal"
  end
end
