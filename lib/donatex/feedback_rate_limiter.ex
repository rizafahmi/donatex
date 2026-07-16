defmodule Donatex.FeedbackRateLimiter do
  @moduledoc false

  use GenServer

  @table __MODULE__
  @cooldown_ms 10_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec check(tuple(), keyword()) :: :ok | {:error, :rate_limited}
  def check(ip, opts \\ []) when is_tuple(ip) and is_list(opts) do
    now = Keyword.get(opts, :now, System.monotonic_time(:millisecond))

    case :ets.lookup(@table, ip) do
      [{^ip, last}] when now - last < @cooldown_ms ->
        {:error, :rate_limited}

      _ ->
        true = :ets.insert(@table, {ip, now})
        :ok
    end
  end

  @impl true
  def init(_opts) do
    _table =
      :ets.new(@table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, %{}}
  end

  @doc false
  def reset do
    case :ets.whereis(@table) do
      :undefined -> :ok
      _tid -> :ets.delete_all_objects(@table)
    end

    :ok
  end
end
