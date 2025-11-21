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

  @doc """
  Returns the component tree structure.

  Builds a hierarchical view of all components based on their
  parent-child relationships in the registry.

  ## Returns

  A list of tree nodes, where each node contains:
  - `:id` - Component identifier
  - `:pid` - Process identifier
  - `:module` - Component module
  - `:children` - List of child nodes

  ## Examples

      tree = ComponentSupervisor.get_tree()
      # [
      #   %{id: :root, pid: #PID<0.123.0>, module: MyApp.Root, children: [
      #     %{id: :child1, pid: #PID<0.124.0>, module: MyApp.Child, children: []}
      #   ]}
      # ]
  """
  @spec get_tree() :: [map()]
  def get_tree do
    # Get all components
    all_components = ComponentRegistry.list_all()

    # Find root components (no parent)
    roots = Enum.filter(all_components, fn {id, _pid} ->
      case ComponentRegistry.get_parent(id) do
        {:ok, nil} -> true
        {:error, :not_found} -> true
        _ -> false
      end
    end)

    # Build tree recursively from roots
    Enum.map(roots, fn {id, pid} ->
      build_tree_node(id, pid)
    end)
  end

  defp build_tree_node(id, pid) do
    # Get component module from server state
    module = try do
      state = TermUI.ComponentServer.get_state(pid)
      Map.get(state, :__module__, :unknown)
    catch
      _, _ -> :unknown
    end

    # Get children
    children = ComponentRegistry.get_children(id)

    child_nodes = Enum.flat_map(children, fn child_id ->
      case ComponentRegistry.lookup(child_id) do
        {:ok, child_pid} -> [build_tree_node(child_id, child_pid)]
        _ -> []
      end
    end)

    %{
      id: id,
      pid: pid,
      module: module,
      children: child_nodes
    }
  end

  @doc """
  Returns detailed information about a component.

  ## Parameters

  - `id` - Component identifier

  ## Returns

  - `{:ok, info}` - Component information map
  - `{:error, :not_found}` - Component not found

  The info map contains:
  - `:id` - Component identifier
  - `:pid` - Process identifier
  - `:module` - Component module
  - `:lifecycle` - Current lifecycle stage
  - `:restart_count` - Number of times restarted
  - `:uptime_ms` - Milliseconds since process started
  - `:state` - Current component state
  - `:props` - Current props

  ## Examples

      {:ok, info} = ComponentSupervisor.get_component_info(:my_button)
      info.uptime_ms
      # => 12345
  """
  @spec get_component_info(term()) :: {:ok, map()} | {:error, :not_found}
  def get_component_info(id) do
    case ComponentRegistry.lookup(id) do
      {:ok, pid} ->
        info = build_component_info(id, pid)
        {:ok, info}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp build_component_info(id, pid) do
    # Get basic info from ComponentServer
    {state, props, lifecycle, module} = try do
      server_state = :sys.get_state(pid)
      {
        Map.get(server_state, :component_state, %{}),
        Map.get(server_state, :props, %{}),
        Map.get(server_state, :lifecycle, :unknown),
        Map.get(server_state, :module, :unknown)
      }
    catch
      _, _ -> {%{}, %{}, :unknown, :unknown}
    end

    # Get restart count from persistence
    restart_count = StatePersistence.get_restart_count(id)

    # Calculate uptime from process info
    uptime_ms = case Process.info(pid, :start_time) do
      {:start_time, start_time} ->
        # start_time is in native time units since VM start
        current = :erlang.monotonic_time(:millisecond)
        start_ms = :erlang.convert_time_unit(start_time, :native, :millisecond)
        current - start_ms

      nil ->
        0
    end

    %{
      id: id,
      pid: pid,
      module: module,
      lifecycle: lifecycle,
      restart_count: restart_count,
      uptime_ms: uptime_ms,
      state: state,
      props: props
    }
  end

  @doc """
  Returns a text visualization of the component tree.

  Useful for debugging and logging.

  ## Examples

      IO.puts(ComponentSupervisor.format_tree())
      # └─ :root (MyApp.Root) #PID<0.123.0>
      #    ├─ :sidebar (MyApp.Sidebar) #PID<0.124.0>
      #    └─ :content (MyApp.Content) #PID<0.125.0>
  """
  @spec format_tree() :: String.t()
  def format_tree do
    tree = get_tree()

    if Enum.empty?(tree) do
      "(no components)"
    else
      tree
      |> Enum.map(&format_tree_node(&1, "", true))
      |> Enum.join("\n")
    end
  end

  defp format_tree_node(node, prefix, is_last) do
    connector = if is_last, do: "└─ ", else: "├─ "
    line = "#{prefix}#{connector}#{inspect(node.id)} (#{inspect(node.module)}) #{inspect(node.pid)}"

    if Enum.empty?(node.children) do
      line
    else
      child_prefix = prefix <> if(is_last, do: "   ", else: "│  ")

      child_lines = node.children
      |> Enum.with_index()
      |> Enum.map(fn {child, idx} ->
        is_last_child = idx == length(node.children) - 1
        format_tree_node(child, child_prefix, is_last_child)
      end)
      |> Enum.join("\n")

      line <> "\n" <> child_lines
    end
  end
end
