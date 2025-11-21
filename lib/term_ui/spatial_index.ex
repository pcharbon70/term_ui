defmodule TermUI.SpatialIndex do
  @moduledoc """
  Spatial index for fast component lookup by screen position.

  The spatial index enables efficient routing of mouse events to
  the correct component based on cursor coordinates. It maintains
  a mapping of screen regions to component references.

  ## Usage

      # Register a component's bounds
      SpatialIndex.update(:my_button, pid, %{x: 10, y: 5, width: 20, height: 3})

      # Find component at position
      {:ok, {:my_button, pid}} = SpatialIndex.find_at(15, 6)

      # Remove when unmounted
      SpatialIndex.remove(:my_button)

  ## Z-Order

  When components overlap, the one with the highest z-index receives
  mouse events. Default z-index is 0. Modals typically use higher values.
  """

  use GenServer

  @table_name :term_ui_spatial_index

  # Client API

  @doc """
  Starts the spatial index.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Updates a component's bounds in the index.

  ## Parameters

  - `id` - Component identifier
  - `pid` - Component process
  - `bounds` - Map with x, y, width, height
  - `opts` - Options including `:z_index`

  ## Examples

      SpatialIndex.update(:button, pid, %{x: 0, y: 0, width: 10, height: 1})
      SpatialIndex.update(:modal, pid, bounds, z_index: 100)
  """
  @spec update(term(), pid(), map(), keyword()) :: :ok
  def update(id, pid, bounds, opts \\ []) do
    z_index = Keyword.get(opts, :z_index, 0)
    GenServer.call(__MODULE__, {:update, id, pid, bounds, z_index})
  end

  @doc """
  Removes a component from the index.
  """
  @spec remove(term()) :: :ok
  def remove(id) do
    GenServer.call(__MODULE__, {:remove, id})
  end

  @doc """
  Finds the component at the given coordinates.

  Returns the topmost component (highest z-index) at the position.

  ## Returns

  - `{:ok, {id, pid}}` - Component found
  - `{:error, :not_found}` - No component at position
  """
  @spec find_at(integer(), integer()) :: {:ok, {term(), pid()}} | {:error, :not_found}
  def find_at(x, y) do
    # Direct ETS lookup for performance
    results =
      :ets.foldl(
        fn {id, pid, bounds, z_index}, acc ->
          if point_in_bounds?(x, y, bounds) do
            [{id, pid, z_index} | acc]
          else
            acc
          end
        end,
        [],
        @table_name
      )

    case results do
      [] ->
        {:error, :not_found}

      matches ->
        # Return highest z-index
        {id, pid, _z} =
          Enum.max_by(matches, fn {_id, _pid, z} -> z end)

        {:ok, {id, pid}}
    end
  end

  @doc """
  Finds all components at the given coordinates.

  Returns all overlapping components sorted by z-index (highest first).
  """
  @spec find_all_at(integer(), integer()) :: [{term(), pid(), integer()}]
  def find_all_at(x, y) do
    :ets.foldl(
      fn {id, pid, bounds, z_index}, acc ->
        if point_in_bounds?(x, y, bounds) do
          [{id, pid, z_index} | acc]
        else
          acc
        end
      end,
      [],
      @table_name
    )
    |> Enum.sort_by(fn {_id, _pid, z} -> z end, :desc)
  end

  @doc """
  Gets the bounds for a component.
  """
  @spec get_bounds(term()) :: {:ok, map()} | {:error, :not_found}
  def get_bounds(id) do
    case :ets.lookup(@table_name, id) do
      [{^id, _pid, bounds, _z}] -> {:ok, bounds}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Clears all entries from the index.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Returns the number of indexed components.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table_name, :size)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:update, id, pid, bounds, z_index}, _from, state) do
    :ets.insert(@table_name, {id, pid, bounds, z_index})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:remove, id}, _from, state) do
    :ets.delete(@table_name, id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, state}
  end

  # Private Functions

  defp point_in_bounds?(x, y, %{x: bx, y: by, width: w, height: h}) do
    x >= bx and x < bx + w and y >= by and y < by + h
  end
end
