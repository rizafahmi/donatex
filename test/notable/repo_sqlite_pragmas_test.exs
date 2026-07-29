defmodule Notable.RepoSqlitePragmasTest do
  use Notable.DataCase, async: false

  alias Ecto.Adapters.SQL

  test "Repo connections use WAL journal mode and busy_timeout 5000" do
    repo_config = Notable.Repo.config()

    assert repo_config[:journal_mode] == :wal
    assert repo_config[:busy_timeout] == 5_000

    %{rows: [[journal_mode]]} = SQL.query!(Repo, "PRAGMA journal_mode", [])
    assert journal_mode == "wal"
  end

  test "Repo default transaction mode is immediate" do
    # Shared config (config.exs) plus env overlays must keep IMMEDIATE so write
    # txs wait on busy_timeout under WAL instead of failing on lock upgrade.
    assert Notable.Repo.config()[:default_transaction_mode] == :immediate

    assert Application.get_env(:notable, Notable.Repo)[:default_transaction_mode] ==
             :immediate
  end
end
