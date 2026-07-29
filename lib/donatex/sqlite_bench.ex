defmodule Donatex.SqliteBench do
  @moduledoc """
  Concurrent SQLite read/write A/B harness for throwaway databases.

  Compares Donatex.Repo production concurrency knobs (WAL + busy_timeout 5000 +
  IMMEDIATE) against a deliberately worse baseline (DELETE journal / busy_timeout
  0 / DEFERRED). Invoked via `mix donatex.sqlite_bench`; not part of `mix ci`.
  """

  require Logger
  @optimized_label "optimized (WAL + busy_timeout=5000 + immediate)"
  @baseline_label "baseline (DELETE + busy_timeout=0 + deferred)"

  @type opts :: %{
          workers: pos_integer(),
          ops_per_worker: pos_integer(),
          write_pct: 1..100,
          keys: pos_integer(),
          seed: integer()
        }

  @type result :: %{
          label: String.t(),
          variant: :optimized | :baseline,
          elapsed_ms: non_neg_integer(),
          attempts: non_neg_integer(),
          success_rate: float(),
          reads: non_neg_integer(),
          writes: non_neg_integer(),
          read_errors: non_neg_integer(),
          write_errors: non_neg_integer(),
          lock_errors: non_neg_integer(),
          other_errors: non_neg_integer(),
          reads_per_sec: float(),
          writes_per_sec: float(),
          ops_per_sec: float()
        }

  def optimized_label, do: @optimized_label
  def baseline_label, do: @baseline_label

  @doc """
  Production-intent knobs matching `Donatex.Repo` in config/config.exs.
  """
  def optimized_repo_opts(database) when is_binary(database) do
    [
      database: database,
      journal_mode: :wal,
      busy_timeout: 5_000,
      default_transaction_mode: :immediate,
      pool_size: 1,
      show_sensitive_data_on_connection_error: true
    ]
  end

  @doc """
  Deliberately worse knobs: rollback journal, no busy wait, deferred txs.
  """
  def baseline_repo_opts(database) when is_binary(database) do
    [
      database: database,
      journal_mode: :delete,
      busy_timeout: 0,
      default_transaction_mode: :deferred,
      pool_size: 1,
      show_sensitive_data_on_connection_error: true
    ]
  end

  @doc """
  True when an exception message indicates SQLite busy / locked contention.
  """
  def lock_error?(exception) do
    message =
      cond do
        is_exception(exception) -> Exception.message(exception)
        is_binary(exception) -> exception
        true -> inspect(exception)
      end

    message = String.downcase(message)

    String.contains?(message, "database is locked") or
      String.contains?(message, "database is busy") or
      String.contains?(message, "database busy") or
      String.contains?(message, "sqlite_busy") or
      (String.contains?(message, "busy") and String.contains?(message, "lock"))
  end

  @doc """
  Default workload options (majority reads, minority writes).
  """
  def default_opts do
    %{
      workers: 8,
      ops_per_worker: 400,
      write_pct: 5,
      keys: 256,
      seed: 64
    }
  end

  @doc """
  Run optimized then baseline on separate throwaway DB files under `dir`.
  """
  def run_ab!(dir, opts \\ %{}) when is_binary(dir) do
    opts = Map.merge(default_opts(), Map.new(opts))
    File.mkdir_p!(dir)

    optimized_db = Path.join(dir, "optimized.db")
    baseline_db = Path.join(dir, "baseline.db")

    Enum.each([optimized_db, baseline_db], &cleanup_db_files/1)

    optimized =
      run_variant!(
        Donatex.SqliteBench.OptimizedRepo,
        :optimized,
        @optimized_label,
        optimized_repo_opts(optimized_db),
        opts
      )

    baseline =
      run_variant!(
        Donatex.SqliteBench.BaselineRepo,
        :baseline,
        @baseline_label,
        baseline_repo_opts(baseline_db),
        opts
      )

    %{optimized: optimized, baseline: baseline, opts: opts}
  end

  @doc """
  Format A/B results for stdout.
  """
  def format_report(%{optimized: optimized, baseline: baseline, opts: opts}) do
    [
      "Donatex SQLite concurrent A/B bench",
      "workload: workers=#{opts.workers} ops/worker=#{opts.ops_per_worker} " <>
        "write_pct=#{opts.write_pct} keys=#{opts.keys} seed=#{opts.seed}",
      "note: baseline busy_timeout=0 fails fast; optimized waits up to 5s so wall ops/sec can look lower while success_rate stays higher",
      "",
      format_result(optimized),
      "",
      format_result(baseline),
      "",
      comparison_line(optimized, baseline)
    ]
    |> Enum.join("\n")
  end

  defp format_result(result) do
    """
    #{result.label}
      elapsed_ms=#{result.elapsed_ms} attempts=#{result.attempts} success_rate=#{format_pct(result.success_rate)}
      reads=#{result.reads} writes=#{result.writes}
      reads/sec=#{format_rate(result.reads_per_sec)} writes/sec=#{format_rate(result.writes_per_sec)} ok_ops/sec=#{format_rate(result.ops_per_sec)}
      lock_errors=#{result.lock_errors} other_errors=#{result.other_errors} (read_errors=#{result.read_errors} write_errors=#{result.write_errors})
    """
    |> String.trim_trailing()
  end

  defp comparison_line(optimized, baseline) do
    "comparison: success_rate optimized=#{format_pct(optimized.success_rate)} baseline=#{format_pct(baseline.success_rate)}; " <>
      "lock_errors optimized=#{optimized.lock_errors} baseline=#{baseline.lock_errors}; " <>
      "ok_ops/sec optimized=#{format_rate(optimized.ops_per_sec)} baseline=#{format_rate(baseline.ops_per_sec)}"
  end

  defp format_rate(rate) when is_float(rate), do: :erlang.float_to_binary(rate, decimals: 1)

  defp format_pct(rate) when is_float(rate),
    do: :erlang.float_to_binary(rate * 100, decimals: 1) <> "%"

  defp run_variant!(repo, variant, label, repo_opts, opts) do
    pool_size = max(opts.workers, 2)
    {:ok, _pid} = repo.start_link(Keyword.put(repo_opts, :pool_size, pool_size))
    previous_log_level = Logger.level()
    Logger.configure(level: :none)

    try do
      setup_schema!(repo)
      seed_rows!(repo, opts.keys)

      parent = self()
      start_ms = System.monotonic_time(:millisecond)

      workers =
        for worker <- 1..opts.workers do
          Task.async(fn ->
            worker_loop(repo, worker, opts, parent)
          end)
        end

      tallies =
        Enum.map(workers, fn task ->
          Task.await(task, :infinity)
        end)

      elapsed_ms = max(System.monotonic_time(:millisecond) - start_ms, 1)
      summarize(label, variant, elapsed_ms, tallies)
    after
      Logger.configure(level: previous_log_level)
      repo.stop(5_000)
    end
  end

  defp worker_loop(repo, worker, opts, _parent) do
    seed = :erlang.phash2({opts.seed, worker})
    :rand.seed(:exsss, {seed, seed + 1, seed + 2})

    Enum.reduce(1..opts.ops_per_worker, empty_tally(), fn _i, tally ->
      key = rem(:rand.uniform(opts.keys) - 1, opts.keys) + 1

      if :rand.uniform(100) <= opts.write_pct do
        run_write(repo, key, tally)
      else
        run_read(repo, key, tally)
      end
    end)
  end

  defp run_read(repo, key, tally) do
    case Ecto.Adapters.SQL.query(repo, "SELECT value FROM bench_items WHERE id = ?", [key]) do
      {:ok, _} ->
        %{tally | reads: tally.reads + 1}

      {:error, error} ->
        bump_error(tally, :read, error)
    end
  rescue
    error ->
      bump_error(tally, :read, error)
  end

  defp run_write(repo, key, tally) do
    value = "v-#{key}-#{System.unique_integer([:positive])}"

    case repo.transaction(fn ->
           case Ecto.Adapters.SQL.query(
                  repo,
                  "INSERT INTO bench_items (id, value) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET value = excluded.value",
                  [key, value]
                ) do
             {:ok, _} -> :ok
             {:error, error} -> repo.rollback(error)
           end
         end) do
      {:ok, :ok} ->
        %{tally | writes: tally.writes + 1}

      {:error, error} ->
        bump_error(tally, :write, error)
    end
  rescue
    error ->
      bump_error(tally, :write, error)
  end

  defp bump_error(tally, kind, error) do
    tally =
      case kind do
        :read -> %{tally | read_errors: tally.read_errors + 1}
        :write -> %{tally | write_errors: tally.write_errors + 1}
      end

    if lock_error?(error) do
      %{tally | lock_errors: tally.lock_errors + 1}
    else
      %{tally | other_errors: tally.other_errors + 1}
    end
  end

  defp empty_tally do
    %{
      reads: 0,
      writes: 0,
      read_errors: 0,
      write_errors: 0,
      lock_errors: 0,
      other_errors: 0
    }
  end

  defp summarize(label, variant, elapsed_ms, tallies) do
    merged = Enum.reduce(tallies, empty_tally(), &merge_tally/2)
    seconds = elapsed_ms / 1000
    ok_ops = merged.reads + merged.writes
    attempts = ok_ops + merged.read_errors + merged.write_errors

    %{
      label: label,
      variant: variant,
      elapsed_ms: elapsed_ms,
      attempts: attempts,
      success_rate: if(attempts == 0, do: 0.0, else: ok_ops / attempts),
      reads: merged.reads,
      writes: merged.writes,
      read_errors: merged.read_errors,
      write_errors: merged.write_errors,
      lock_errors: merged.lock_errors,
      other_errors: merged.other_errors,
      reads_per_sec: merged.reads / seconds,
      writes_per_sec: merged.writes / seconds,
      ops_per_sec: ok_ops / seconds
    }
  end

  defp merge_tally(left, right) do
    %{
      reads: left.reads + right.reads,
      writes: left.writes + right.writes,
      read_errors: left.read_errors + right.read_errors,
      write_errors: left.write_errors + right.write_errors,
      lock_errors: left.lock_errors + right.lock_errors,
      other_errors: left.other_errors + right.other_errors
    }
  end

  defp setup_schema!(repo) do
    {:ok, _} =
      Ecto.Adapters.SQL.query(
        repo,
        """
        CREATE TABLE IF NOT EXISTS bench_items (
          id INTEGER PRIMARY KEY NOT NULL,
          value TEXT NOT NULL
        )
        """,
        []
      )

    :ok
  end

  defp seed_rows!(repo, keys) do
    repo.transaction(fn ->
      for id <- 1..keys do
        {:ok, _} =
          Ecto.Adapters.SQL.query(
            repo,
            "INSERT OR IGNORE INTO bench_items (id, value) VALUES (?, ?)",
            [id, "seed-#{id}"]
          )
      end

      :ok
    end)
    |> case do
      {:ok, :ok} -> :ok
      other -> raise "failed to seed bench rows: #{inspect(other)}"
    end
  end

  defp cleanup_db_files(path) do
    for suffix <- ["", "-wal", "-shm", "-journal"] do
      file = path <> suffix
      if File.exists?(file), do: File.rm!(file)
    end
  end
end

defmodule Donatex.SqliteBench.OptimizedRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :donatex, adapter: Ecto.Adapters.SQLite3
end

defmodule Donatex.SqliteBench.BaselineRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :donatex, adapter: Ecto.Adapters.SQLite3
end
