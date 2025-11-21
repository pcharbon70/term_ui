defmodule TermUI.Component.StatePersistence do
  @moduledoc """
  ETS-based state persistence for crash recovery.

  This module allows components to persist their state before crashes
  and recover it on restart. State is stored in an ETS table that survives
  component process crashes.

  ## Usage

      # Persist state (typically called on state changes)
      StatePersistence.persist(:my_component, state)

      # Recover state on restart
      case StatePersistence.recover(:my_component) do
        {:ok, state} -> {:ok, state}
        :not_found -> {:ok, initial_state}
      end

      # Clear persisted state
      StatePersistence.clear(:my_component)
  """

  use GenServer

  @table_name :term_ui_component_states
  @metadata_table :term_ui_persistence_metadata

  # Client API

  @doc """
  Starts the state persistence server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Persists component state to ETS.

  ## Parameters

  - `component_id` - Component identifier
  - `state` - State to persist
  - `opts` - Options
    - `:props` - Original props for last_props recovery mode

  ## Returns

  - `:ok` - State persisted successfully
  """
  @spec persist(term(), term(), keyword()) :: :ok
  def persist(component_id, state, opts \\ []) do
    props = Keyword.get(opts, :props)

    entry = %{
      state: state,
      props: props,
      persisted_at: System.system_time(:millisecond)
    }

    :ets.insert(@table_name, {component_id, entry})
    :ok
  end

  @doc """
  Recovers persisted state for a component.

  ## Parameters

  - `component_id` - Component identifier
  - `mode` - Recovery mode (default: `:last_state`)
    - `:last_state` - Return the full persisted state
    - `:last_props` - Return only the persisted props
    - `:reset` - Return :not_found (forces re-initialization)

  ## Returns

  - `{:ok, state}` - State found and returned
  - `:not_found` - No state persisted for this component
  """
  @spec recover(term(), atom()) :: {:ok, term()} | :not_found
  def recover(component_id, mode \\ :last_state) do
    case mode do
      :reset ->
        # Clear any persisted state and return not found
        clear(component_id)
        :not_found

      :last_state ->
        case :ets.lookup(@table_name, component_id) do
          [{^component_id, %{state: state}}] -> {:ok, state}
          [] -> :not_found
        end

      :last_props ->
        case :ets.lookup(@table_name, component_id) do
          [{^component_id, %{props: props}}] when not is_nil(props) -> {:ok, props}
          _ -> :not_found
        end
    end
  end

  @doc """
  Clears persisted state for a component.

  ## Parameters

  - `component_id` - Component identifier

  ## Returns

  - `:ok` - State cleared (or was not present)
  """
  @spec clear(term()) :: :ok
  def clear(component_id) do
    :ets.delete(@table_name, component_id)
    :ok
  end

  @doc """
  Clears all persisted state.

  Mainly useful for testing.
  """
  @spec clear_all() :: :ok
  def clear_all do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  @doc """
  Gets metadata about persisted state.

  ## Returns

  - `{:ok, metadata}` - Metadata including persisted_at timestamp
  - `:not_found` - No state persisted for this component
  """
  @spec get_metadata(term()) :: {:ok, map()} | :not_found
  def get_metadata(component_id) do
    case :ets.lookup(@table_name, component_id) do
      [{^component_id, entry}] ->
        {:ok, %{
          persisted_at: entry.persisted_at,
          has_props: not is_nil(entry.props)
        }}
      [] ->
        :not_found
    end
  end

  @doc """
  Lists all component IDs with persisted state.
  """
  @spec list_persisted() :: [term()]
  def list_persisted do
    @table_name
    |> :ets.tab2list()
    |> Enum.map(fn {id, _entry} -> id end)
  end

  @doc """
  Returns the count of persisted states.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table_name, :size)
  end

  @doc """
  Records restart event for a component.

  Used for tracking restart counts and detecting restart storms.
  """
  @spec record_restart(term()) :: :ok
  def record_restart(component_id) do
    now = System.system_time(:second)

    case :ets.lookup(@metadata_table, component_id) do
      [{^component_id, metadata}] ->
        # Remove restarts older than max_seconds window (default 5 seconds)
        max_seconds = Map.get(metadata, :max_seconds, 5)
        cutoff = now - max_seconds

        restarts =
          metadata.restarts
          |> Enum.filter(fn ts -> ts > cutoff end)
          |> then(fn list -> list ++ [now] end)

        new_metadata = %{metadata | restarts: restarts}
        :ets.insert(@metadata_table, {component_id, new_metadata})

      [] ->
        metadata = %{
          restarts: [now],
          max_restarts: 3,
          max_seconds: 5
        }
        :ets.insert(@metadata_table, {component_id, metadata})
    end

    :ok
  end

  @doc """
  Gets the restart count for a component within the time window.
  """
  @spec get_restart_count(term()) :: non_neg_integer()
  def get_restart_count(component_id) do
    case :ets.lookup(@metadata_table, component_id) do
      [{^component_id, metadata}] -> length(metadata.restarts)
      [] -> 0
    end
  end

  @doc """
  Checks if restart intensity limit has been reached.

  ## Returns

  - `true` - Restart limit exceeded
  - `false` - Within limits
  """
  @spec restart_limit_reached?(term()) :: boolean()
  def restart_limit_reached?(component_id) do
    case :ets.lookup(@metadata_table, component_id) do
      [{^component_id, metadata}] ->
        length(metadata.restarts) >= metadata.max_restarts

      [] ->
        false
    end
  end

  @doc """
  Sets restart intensity limits for a component.

  ## Parameters

  - `component_id` - Component identifier
  - `max_restarts` - Maximum restarts allowed
  - `max_seconds` - Time window in seconds
  """
  @spec set_restart_limits(term(), non_neg_integer(), non_neg_integer()) :: :ok
  def set_restart_limits(component_id, max_restarts, max_seconds) do
    case :ets.lookup(@metadata_table, component_id) do
      [{^component_id, metadata}] ->
        new_metadata = %{metadata | max_restarts: max_restarts, max_seconds: max_seconds}
        :ets.insert(@metadata_table, {component_id, new_metadata})

      [] ->
        metadata = %{
          restarts: [],
          max_restarts: max_restarts,
          max_seconds: max_seconds
        }
        :ets.insert(@metadata_table, {component_id, metadata})
    end

    :ok
  end

  @doc """
  Clears restart history for a component.
  """
  @spec clear_restart_history(term()) :: :ok
  def clear_restart_history(component_id) do
    :ets.delete(@metadata_table, component_id)
    :ok
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS tables
    :ets.new(@table_name, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.new(@metadata_table, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{}}
  end
end
