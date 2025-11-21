defmodule TermUI.ComponentSupervisor do
  @moduledoc """
  Dynamic supervisor for managing component processes.

  Components are spawned as child processes under this supervisor,
  providing fault isolation and automatic cleanup. Each component
  runs as a GenServer managed by `TermUI.ComponentServer`.

  ## Usage

      # Start a component under the supervisor
      {:ok, pid} = ComponentSupervisor.start_component(MyComponent, %{text: "Hello"})

      # Stop a component
      :ok = ComponentSupervisor.stop_component(pid)

      # Stop with cascade (stops all children)
      :ok = ComponentSupervisor.stop_component(pid, cascade: true)

  ## Supervision Strategy

  Uses `:one_for_one` strategy - each component is independent.
  Default restart is `:transient` - restart only on crash, not normal exit.

  ## Restart Strategies

  - `:transient` (default) - Restart only on abnormal termination
  - `:permanent` - Always restart on termination
  - `:temporary` - Never restart

  ## Shutdown Options

  - `:shutdown` - Timeout in ms (default 5000) or `:brutal_kill`
  - `:recovery` - Recovery mode: `:reset`, `:last_props`, `:last_state`
  """

  use DynamicSupervisor

  require Logger

  alias TermUI.ComponentRegistry
  alias TermUI.Component.StatePersistence

  @default_shutdown_timeout 5_000

  @doc """
  Starts the component supervisor.

  Called by the application supervisor during startup.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    max_restarts = Keyword.get(opts, :max_restarts, 3)
    max_seconds = Keyword.get(opts, :max_seconds, 5)

    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: max_restarts,
      max_seconds: max_seconds
    )
  end

  @doc """
  Starts a component under the supervisor.

  ## Parameters

  - `module` - The component module implementing a behaviour
  - `props` - Initial properties for the component
  - `opts` - Options including `:id` for component identification

  ## Options

  - `:id` - Component identifier for registry lookup
  - `:name` - Process name registration
  - `:timeout` - Init timeout in milliseconds (default 5000)
  - `:restart` - Restart strategy: `:transient`, `:permanent`, `:temporary` (default `:transient`)
  - `:shutdown` - Shutdown timeout in ms or `:brutal_kill` (default 5000)
  - `:recovery` - Recovery mode: `:reset`, `:last_props`, `:last_state` (default `:last_state`)

  ## Returns

  - `{:ok, pid}` - Component started successfully
  - `{:error, reason}` - Failed to start

  ## Examples

      {:ok, pid} = ComponentSupervisor.start_component(Label, %{text: "Hello"})

      {:ok, pid} = ComponentSupervisor.start_component(
        Button,
        %{label: "Click"},
        id: :submit_button
      )
  """
  @spec start_component(module(), map(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_component(module, props, opts \\ []) do
    component_id = Keyword.get(opts, :id, make_ref())
    restart = Keyword.get(opts, :restart, :transient)
    shutdown = Keyword.get(opts, :shutdown, @default_shutdown_timeout)
    recovery = Keyword.get(opts, :recovery, :last_state)

    # Store recovery mode for state persistence
    full_opts = Keyword.put(opts, :recovery, recovery)

    # Set restart limits for this component if specified
    if Keyword.has_key?(opts, :max_restarts) do
      max_restarts = Keyword.get(opts, :max_restarts, 3)
      max_seconds = Keyword.get(opts, :max_seconds, 5)
      StatePersistence.set_restart_limits(component_id, max_restarts, max_seconds)
    end

    child_spec = %{
      id: component_id,
      start: {TermUI.ComponentServer, :start_link, [module, props, full_opts]},
      restart: restart,
      shutdown: shutdown,
      type: :worker
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stops a component gracefully.

  Triggers the unmount lifecycle before termination.

  ## Parameters

  - `pid_or_id` - The component process pid or id
  - `opts` - Options
    - `:cascade` - Also stop all child components (default: false)

  ## Returns

  - `:ok` - Component stopped successfully
  - `{:error, :not_found}` - Component not found
  """
  @spec stop_component(pid() | term(), keyword()) :: :ok | {:error, :not_found}
  def stop_component(pid_or_id, opts \\ [])

  def stop_component(pid, opts) when is_pid(pid) do
    cascade = Keyword.get(opts, :cascade, false)

    # If cascade, find and stop children first
    if cascade do
      case ComponentRegistry.lookup_id(pid) do
        {:ok, id} ->
          stop_children(id)
        _ ->
          :ok
      end
    end

    case DynamicSupervisor.terminate_child(__MODULE__, pid) do
      :ok -> :ok
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def stop_component(id, opts) do
    case ComponentRegistry.lookup(id) do
      {:ok, pid} -> stop_component(pid, opts)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp stop_children(parent_id) do
    children = ComponentRegistry.get_children(parent_id)

    # Stop children in reverse order (depth-first)
    Enum.each(children, fn child_id ->
      # Recursively stop grandchildren first
      stop_children(child_id)

      # Then stop the child
      case ComponentRegistry.lookup(child_id) do
        {:ok, pid} ->
          DynamicSupervisor.terminate_child(__MODULE__, pid)
        _ ->
          :ok
      end
    end)
  end

  @doc """
  Returns the count of running components.
  """
  @spec count_children() :: non_neg_integer()
  def count_children do
    %{workers: count} = DynamicSupervisor.count_children(__MODULE__)
    count
  end

  @doc """
  Returns all component pids.
  """
  @spec which_children() :: [pid()]
  def which_children do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&is_pid/1)
  end
end
