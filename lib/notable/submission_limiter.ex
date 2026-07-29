defmodule Notable.SubmissionLimiter do
  @moduledoc false

  use GenServer

  @table __MODULE__
  @cooldown_ms 10_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Reserve a submission slot for a namespaced key (e.g. `{:feedback, ip}`,
  `{:tip, ip}`, or `{:question, visitor_id}`). Returns `:ok` when reserved, or
  `{:error, :rate_limited}` when the key is still within the cooldown window.
  """
  @spec reserve(term(), keyword()) :: :ok | {:error, :rate_limited}
  def reserve(key, opts \\ []) when is_list(opts) do
    now = Keyword.get(opts, :now, System.monotonic_time(:millisecond))
    GenServer.call(__MODULE__, {:reserve, key, now})
  end

  @doc "Release a reservation early (e.g. on a failed validation/persistence)."
  @spec release(term()) :: :ok
  def release(key) do
    GenServer.call(__MODULE__, {:release, key})
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

  @impl true
  def handle_call({:reserve, key, now}, _from, state) do
    reply =
      case :ets.lookup(@table, key) do
        [{^key, last}] when now - last < @cooldown_ms ->
          {:error, :rate_limited}

        _ ->
          true = :ets.insert(@table, {key, now})
          :ok
      end

    {:reply, reply, state}
  end

  def handle_call({:release, key}, _from, state) do
    :ets.delete(@table, key)
    {:reply, :ok, state}
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
