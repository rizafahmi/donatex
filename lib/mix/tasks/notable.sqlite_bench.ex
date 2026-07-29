defmodule Mix.Tasks.Notable.SqliteBench do
  @shortdoc "A/B concurrent SQLite read/write bench (opt vs baseline)"

  @moduledoc """
  Runs a reproducible concurrent read/write workload against two throwaway
  SQLite databases in-process:

  1. **optimized** — matches `Notable.Repo` production intent:
     `journal_mode: :wal`, `busy_timeout: 5_000`, `default_transaction_mode: :immediate`
  2. **baseline** — deliberately worse:
     `journal_mode: :delete`, `busy_timeout: 0`, `default_transaction_mode: :deferred`

  Prints throughput (reads/sec, writes/sec, ops/sec) and lock-error counts.

  ## Examples

      mix notable.sqlite_bench
      mix notable.sqlite_bench --workers 16 --ops 800 --write-pct 5

  Optional / manual only — not invoked by `mix ci`.

  See also `docs/OPERATIONS.md` (SQLite Notes) for when this fits ops workflows.
  """

  use Mix.Task

  @requirements ["app.config"]

  @switches [
    workers: :integer,
    ops: :integer,
    write_pct: :integer,
    keys: :integer,
    seed: :integer,
    dir: :string
  ]

  @impl Mix.Task
  def run(args) do
    {parsed, _argv, invalid} = OptionParser.parse(args, strict: @switches)

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    ensure_started!()

    opts =
      %{}
      |> maybe_put(:workers, parsed[:workers])
      |> maybe_put(:ops_per_worker, parsed[:ops])
      |> maybe_put(:write_pct, parsed[:write_pct])
      |> maybe_put(:keys, parsed[:keys])
      |> maybe_put(:seed, parsed[:seed])

    validate_opts!(opts)

    dir =
      parsed[:dir] ||
        Path.join(System.tmp_dir!(), "notable-sqlite-bench-#{System.unique_integer([:positive])}")

    Mix.shell().info("throwaway dir: #{dir}")
    report = Notable.SqliteBench.run_ab!(dir, opts) |> Notable.SqliteBench.format_report()
    Mix.shell().info(report)
  end

  defp ensure_started! do
    {:ok, _} = Application.ensure_all_started(:ssl)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:exqlite)
    :ok
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp validate_opts!(opts) do
    Enum.each(opts, fn
      {:workers, n} when is_integer(n) and n >= 1 -> :ok
      {:ops_per_worker, n} when is_integer(n) and n >= 1 -> :ok
      {:write_pct, n} when is_integer(n) and n in 1..100 -> :ok
      {:keys, n} when is_integer(n) and n >= 1 -> :ok
      {:seed, n} when is_integer(n) -> :ok
      {key, value} -> Mix.raise("invalid #{key}: #{inspect(value)}")
    end)
  end
end
