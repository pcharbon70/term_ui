defmodule TermUI.ComponentRegistry do
  @moduledoc """
  ETS-based registry for component lookup.

  The registry enables fast lookup of component processes by id,
  which is essential for event routing and focus management.
  Components register on mount and unregister on unmount.

  ## Usage

      # Register a component
      ComponentRegistry.register(:my_button, pid, Button)

      # Lookup by id
      {:ok, pid} = ComponentRegistry.lookup(:my_button)

      # Lookup by pid
      {:ok, id} = ComponentRegistry.lookup_id(pid)

      # List all
      components = ComponentRegistry.list_all()
  """

  use GenServer

  @table_name :term_ui_component_registry
  @pid_index :term_ui_component_pid_index
  @parent_table :term_ui_component_parents

  # Client API

  @doc """
  Starts the component registry.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a component in the registry.

  ## Parameters

  - `id` - Unique identifier for the component
  - `pid` - Process pid of the component
  - `module` - Component module

  ## Returns

  - `:ok` - Successfully registered
  - `{:error, :already_registered}` - Id already taken
  """
  @spec register(term(), pid(), module()) :: :ok | {:error, :already_registered}
  def register(id, pid, module) when is_pid(pid) and is_atom(module) do
    GenServer.call(__MODULE__, {:register, id, pid, module})
  end

  @doc """
  Unregisters a component from the registry.

  ## Parameters

  - `id` - Component identifier to unregister

  ## Returns

  - `:ok` - Successfully unregistered (or wasn't registered)
  """
  @spec unregister(term()) :: :ok
  def unregister(id) do
    GenServer.call(__MODULE__, {:unregister, id})
  end

  @doc """
  Looks up a component by id.

  ## Returns

  - `{:ok, pid}` - Component found
  - `{:error, :not_found}` - Component not registered
  """
  @spec lookup(term()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(id) do
    case :ets.lookup(@table_name, id) do
      [{^id, pid, _module}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Looks up a component id by pid.

  ## Returns

  - `{:ok, id}` - Component found
  - `{:error, :not_found}` - Component not registered
  """
  @spec lookup_id(pid()) :: {:ok, term()} | {:error, :not_found}
  def lookup_id(pid) when is_pid(pid) do
    case :ets.lookup(@pid_index, pid) do
      [{^pid, id}] -> {:ok, id}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Gets full component info by id.

  ## Returns

  - `{:ok, %{id: term(), pid: pid(), module: module()}}` - Component found
  - `{:error, :not_found}` - Component not registered
  """
  @spec get_info(term()) :: {:ok, map()} | {:error, :not_found}
  def get_info(id) do
    case :ets.lookup(@table_name, id) do
      [{^id, pid, module}] ->
        {:ok, %{id: id, pid: pid, module: module}}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Lists all registered components.

  ## Returns

  List of `%{id: term(), pid: pid(), module: module()}`
  """
  @spec list_all() :: [map()]
  def list_all do
    @table_name
    |> :ets.tab2list()
    |> Enum.map(fn {id, pid, module} ->
      %{id: id, pid: pid, module: module}
    end)
  end

  @doc """
  Returns the count of registered components.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table_name, :size)
  end

  @doc """
  Checks if a component is registered.
  """
  @spec registered?(term()) :: boolean()
  def registered?(id) do
    :ets.member(@table_name, id)
  end

  @doc """
  Clears all registrations.

  Mainly useful for testing.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Sets the parent of a component for propagation.

  ## Parameters

  - `id` - Component id
  - `parent_id` - Parent component id (or nil for root)
  """
  @spec set_parent(term(), term() | nil) :: :ok
  def set_parent(id, parent_id) do
    :ets.insert(@parent_table, {id, parent_id})
    :ok
  end

  @doc """
  Gets the parent of a component.

  ## Returns

  - `{:ok, parent_id}` - Parent found (nil if root)
  - `{:error, :not_found}` - Component not in parent table
  """
  @spec get_parent(term()) :: {:ok, term() | nil} | {:error, :not_found}
  def get_parent(id) do
    case :ets.lookup(@parent_table, id) do
      [{^id, parent_id}] -> {:ok, parent_id}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Gets all children of a component.

  ## Returns

  List of child component ids.
  """
  @spec get_children(term()) :: [term()]
  def get_children(parent_id) do
    @parent_table
    |> :ets.tab2list()
    |> Enum.filter(fn {_id, pid} -> pid == parent_id end)
    |> Enum.map(fn {id, _pid} -> id end)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS tables
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@pid_index, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@parent_table, [:set, :public, :named_table, read_concurrency: true])

    {:ok, %{monitors: %{}}}
  end

  @impl true
  def handle_call({:register, id, pid, module}, _from, state) do
    case :ets.lookup(@table_name, id) do
      [] ->
        # Insert into both tables
        :ets.insert(@table_name, {id, pid, module})
        :ets.insert(@pid_index, {pid, id})

        # Monitor the process for automatic cleanup
        ref = Process.monitor(pid)
        monitors = Map.put(state.monitors, ref, id)

        {:reply, :ok, %{state | monitors: monitors}}

      [_existing] ->
        {:reply, {:error, :already_registered}, state}
    end
  end

  @impl true
  def handle_call({:unregister, id}, _from, state) do
    case :ets.lookup(@table_name, id) do
      [{^id, pid, _module}] ->
        # Remove from both tables
        :ets.delete(@table_name, id)
        :ets.delete(@pid_index, pid)

        # Find and remove monitor
        {ref, monitors} = find_and_remove_monitor(state.monitors, id)

        if ref, do: Process.demonitor(ref, [:flush])

        {:reply, :ok, %{state | monitors: monitors}}

      [] ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    :ets.delete_all_objects(@pid_index)
    :ets.delete_all_objects(@parent_table)

    # Demonitor all
    Enum.each(state.monitors, fn {ref, _id} ->
      Process.demonitor(ref, [:flush])
    end)

    {:reply, :ok, %{state | monitors: %{}}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.pop(state.monitors, ref) do
      {nil, monitors} ->
        {:noreply, %{state | monitors: monitors}}

      {id, monitors} ->
        # Clean up the registration
        case :ets.lookup(@table_name, id) do
          [{^id, pid, _module}] ->
            :ets.delete(@table_name, id)
            :ets.delete(@pid_index, pid)

          [] ->
            :ok
        end

        {:noreply, %{state | monitors: monitors}}
    end
  end

  defp find_and_remove_monitor(monitors, id) do
    monitors
    |> Enum.find_value(fn {ref, monitored_id} ->
      if monitored_id == id, do: {ref, Map.delete(monitors, ref)}
    end) || {nil, monitors}
  end
end
