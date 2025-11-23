defmodule TermUI.Layout.Cache do
  @moduledoc """
  Layout cache with LRU eviction for caching constraint solver results.

  The cache stores solved layouts keyed by constraint hash and dimensions,
  providing O(1) lookup for unchanged layouts. LRU eviction keeps memory
  bounded while maintaining frequently-used layouts.

  ## Usage

      # Start cache (typically in supervision tree)
      Cache.start_link(max_size: 1000)

      # Cached solve
      rects = Cache.solve(constraints, area)

      # Statistics
      stats = Cache.stats()
      # => %{size: 150, hits: 1234, misses: 56, hit_rate: 0.956}

      # Clear on resize
      Cache.clear()

  ## Configuration

  - `:max_size` - Maximum entries before eviction (default 500)
  - `:eviction_count` - Entries to remove per eviction (default 50)
  """

  use GenServer

  alias TermUI.Layout.Solver

  @table :term_ui_layout_cache
  @stats_table :term_ui_layout_cache_stats
  @default_max_size 500
  @default_eviction_count 50

  # Client API

  @doc """
  Starts the layout cache.

  ## Options

  - `:max_size` - Maximum cache entries (default 500)
  - `:eviction_count` - Entries to remove per eviction (default 50)
  - `:name` - GenServer name (default __MODULE__)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Solves constraints with automatic caching.

  Checks cache first, falls back to solver on miss.

  ## Parameters

  - `constraints` - list of constraints
  - `area` - bounding rectangle
  - `opts` - solver options (direction, gap, etc.)

  ## Returns

  List of positioned rectangles.
  """
  def solve(constraints, area, opts \\ []) do
    key = cache_key(constraints, area)

    case lookup(key) do
      {:ok, result} ->
        increment_hits()
        result

      :miss ->
        increment_misses()
        result = Solver.solve_to_rects(constraints, area, opts)
        insert(key, result)
        result
    end
  end

  @doc """
  Solves constraints without caching.

  Use for testing or when caching is not desired.
  """
  def solve_uncached(constraints, area, opts \\ []) do
    Solver.solve_to_rects(constraints, area, opts)
  end

  @doc """
  Looks up a cached result by key.

  Returns `{:ok, result}` if found, `:miss` otherwise.
  """
  def lookup(key) do
    case :ets.lookup(@table, key) do
      [{^key, result, _access_time}] ->
        # Update access time
        :ets.update_element(@table, key, {3, current_time()})
        {:ok, result}

      [] ->
        :miss
    end
  end

  @doc """
  Inserts a result into the cache.

  Triggers eviction if cache exceeds max size.
  """
  def insert(key, result) do
    now = current_time()
    :ets.insert(@table, {key, result, now})
    maybe_evict()
    :ok
  end

  @doc """
  Invalidates a specific cache entry.
  """
  def invalidate(key) do
    :ets.delete(@table, key)
    :ok
  end

  @doc """
  Invalidates cache entries matching constraints.

  Useful when a component's constraints change.
  """
  def invalidate_constraints(constraints) do
    hash = constraint_hash(constraints)

    # Find and delete all entries with this constraint hash
    :ets.select_delete(@table, [
      {{{hash, :_, :_}, :_, :_}, [], [true]}
    ])

    :ok
  end

  @doc """
  Clears all cache entries.

  Call this on terminal resize.
  """
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc """
  Returns cache statistics.

  ## Returns

  Map with:
  - `:size` - current entry count
  - `:hits` - total cache hits
  - `:misses` - total cache misses
  - `:hit_rate` - hits / (hits + misses)
  """
  def stats do
    size = :ets.info(@table, :size)

    [{_, hits}] = :ets.lookup(@stats_table, :hits)
    [{_, misses}] = :ets.lookup(@stats_table, :misses)

    total = hits + misses

    hit_rate =
      if total > 0 do
        Float.round(hits / total, 3)
      else
        0.0
      end

    %{
      size: size,
      hits: hits,
      misses: misses,
      hit_rate: hit_rate
    }
  end

  @doc """
  Resets cache statistics.
  """
  def reset_stats do
    :ets.insert(@stats_table, {:hits, 0})
    :ets.insert(@stats_table, {:misses, 0})
    :ok
  end

  @doc """
  Warms the cache with common layouts.

  ## Parameters

  - `layouts` - list of `{constraints, area, opts}` tuples
  """
  def warm(layouts) when is_list(layouts) do
    Enum.each(layouts, fn {constraints, area, opts} ->
      solve(constraints, area, opts)
    end)

    # Reset stats after warming so they reflect actual usage
    reset_stats()
    :ok
  end

  @doc """
  Returns the current cache size.
  """
  def size do
    :ets.info(@table, :size)
  end

  @doc """
  Forces eviction synchronously. Useful for testing.
  """
  def evict_now(name \\ __MODULE__) do
    GenServer.call(name, :evict_sync)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    max_size = Keyword.get(opts, :max_size, @default_max_size)
    eviction_count = Keyword.get(opts, :eviction_count, @default_eviction_count)

    # Create ETS tables
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@stats_table, [:set, :public, :named_table])

    # Initialize stats
    :ets.insert(@stats_table, {:hits, 0})
    :ets.insert(@stats_table, {:misses, 0})

    state = %{
      max_size: max_size,
      eviction_count: eviction_count
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_config, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:evict_sync, _from, state) do
    do_eviction(state.max_size, state.eviction_count)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:evict, state) do
    do_eviction(state.max_size, state.eviction_count)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    # Clean up ETS tables
    if :ets.whereis(@table) != :undefined, do: :ets.delete(@table)
    if :ets.whereis(@stats_table) != :undefined, do: :ets.delete(@stats_table)
    :ok
  end

  # Private functions

  defp cache_key(constraints, area) do
    hash = constraint_hash(constraints)
    {hash, area.width, area.height}
  end

  defp constraint_hash(constraints) do
    :erlang.phash2(constraints)
  end

  defp current_time do
    :erlang.monotonic_time(:millisecond)
  end

  defp increment_hits do
    :ets.update_counter(@stats_table, :hits, 1)
  end

  defp increment_misses do
    :ets.update_counter(@stats_table, :misses, 1)
  end

  defp maybe_evict do
    current_size = :ets.info(@table, :size)
    config = get_config()

    if current_size > config.max_size do
      GenServer.cast(__MODULE__, :evict)
    end
  end

  defp get_config do
    GenServer.call(__MODULE__, :get_config, 100)
  catch
    :exit, _ ->
      %{max_size: @default_max_size, eviction_count: @default_eviction_count}
  end

  defp do_eviction(max_size, eviction_count) do
    current_size = :ets.info(@table, :size)

    if current_size > max_size do
      # Get all entries sorted by access time
      entries =
        :ets.tab2list(@table)
        |> Enum.sort_by(fn {_key, _result, access_time} -> access_time end)

      # Remove oldest entries
      to_remove = min(eviction_count, current_size - max_size + eviction_count)

      entries
      |> Enum.take(to_remove)
      |> Enum.each(fn {key, _result, _access_time} ->
        :ets.delete(@table, key)
      end)
    end
  end
end
