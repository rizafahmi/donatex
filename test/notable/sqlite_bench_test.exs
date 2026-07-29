defmodule Notable.SqliteBenchTest do
  use ExUnit.Case, async: true

  alias Notable.SqliteBench

  test "optimized repo opts match Notable.Repo production concurrency knobs" do
    opts = SqliteBench.optimized_repo_opts("/tmp/opt.db")

    assert opts[:journal_mode] == :wal
    assert opts[:busy_timeout] == 5_000
    assert opts[:default_transaction_mode] == :immediate
    assert opts[:database] == "/tmp/opt.db"
  end

  test "baseline repo opts are deliberately worse than production" do
    opts = SqliteBench.baseline_repo_opts("/tmp/base.db")

    assert opts[:journal_mode] == :delete
    assert opts[:busy_timeout] == 0
    assert opts[:default_transaction_mode] == :deferred
  end

  test "lock_error?/1 detects sqlite busy and locked messages" do
    assert SqliteBench.lock_error?(%RuntimeError{message: "database is locked"})
    assert SqliteBench.lock_error?(%RuntimeError{message: "SQLITE_BUSY: database is busy"})
    assert SqliteBench.lock_error?(%RuntimeError{message: "Database busy"})
    refute SqliteBench.lock_error?(%RuntimeError{message: "no such table: missing"})
  end

  test "format_report includes both labels and comparison line" do
    report =
      SqliteBench.format_report(%{
        opts: SqliteBench.default_opts(),
        optimized: sample_result(:optimized, SqliteBench.optimized_label(), 1000.0, 0),
        baseline: sample_result(:baseline, SqliteBench.baseline_label(), 100.0, 12)
      })

    assert report =~ SqliteBench.optimized_label()
    assert report =~ SqliteBench.baseline_label()
    assert report =~ "comparison:"
    assert report =~ "lock_errors optimized=0 baseline=12"
    assert report =~ "success_rate"
  end

  test "run_ab! completes optimized vs baseline and reports both variants" do
    dir =
      Path.join(
        System.tmp_dir!(),
        "notable-sqlite-bench-test-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf(dir) end)

    %{optimized: optimized, baseline: baseline, opts: opts} =
      SqliteBench.run_ab!(dir, %{
        workers: 4,
        ops_per_worker: 25,
        write_pct: 10,
        keys: 32,
        seed: 64
      })

    assert opts.workers == 4
    assert optimized.variant == :optimized
    assert baseline.variant == :baseline
    assert optimized.attempts == 100
    assert baseline.attempts == 100
    assert optimized.success_rate >= baseline.success_rate

    report = SqliteBench.format_report(%{optimized: optimized, baseline: baseline, opts: opts})
    assert report =~ "Notable SQLite concurrent A/B bench"
    assert report =~ SqliteBench.optimized_label()
    assert report =~ SqliteBench.baseline_label()
    assert report =~ "comparison:"
  end

  defp sample_result(variant, label, ops_per_sec, lock_errors) do
    reads = trunc(ops_per_sec * 0.95)
    writes = trunc(ops_per_sec * 0.05)
    ok = reads + writes
    attempts = ok + lock_errors

    %{
      label: label,
      variant: variant,
      elapsed_ms: 1000,
      attempts: attempts,
      success_rate: ok / attempts,
      reads: reads,
      writes: writes,
      read_errors: 0,
      write_errors: lock_errors,
      lock_errors: lock_errors,
      other_errors: 0,
      reads_per_sec: ops_per_sec * 0.95,
      writes_per_sec: ops_per_sec * 0.05,
      ops_per_sec: ops_per_sec
    }
  end
end
