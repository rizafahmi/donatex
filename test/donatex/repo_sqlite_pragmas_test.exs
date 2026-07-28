defmodule Donatex.RepoSqlitePragmasTest do
  use Donatex.DataCase, async: false

  alias Ecto.Adapters.SQL

  test "Repo connections use WAL journal mode and a non-zero busy_timeout" do
    repo_config = Donatex.Repo.config()

    assert repo_config[:journal_mode] == :wal
    assert is_integer(repo_config[:busy_timeout])
    assert repo_config[:busy_timeout] > 0

    %{rows: [[journal_mode]]} = SQL.query!(Repo, "PRAGMA journal_mode", [])
    assert journal_mode == "wal"
  end
end
