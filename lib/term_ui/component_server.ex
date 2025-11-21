defmodule TermUI.ComponentServer do
  @moduledoc """
  GenServer that manages the lifecycle of a component.

  ComponentServer wraps any component implementing TermUI behaviours,
  managing its lifecycle stages: init, mount, update, and unmount.
  It handles prop validation, timeout enforcement, and command execution.

  ## Lifecycle Stages

  1. **Init** - Create initial state from props
  2. **Mount** - Component enters active tree, ready for events
  3. **Update** - Props changed, state may update
  4. **Unmount** - Component removed, cleanup performed

  ## Usage

  Components are typically started via `ComponentSupervisor`:

      {:ok, pid} = ComponentSupervisor.start_component(MyButton, %{label: "OK"})

  Direct usage:

      {:ok, pid} = ComponentServer.start_link(MyButton, %{label: "OK"}, [])
  """

  use GenServer

  require Logger

  alias TermUI.ComponentRegistry

  @default_init_timeout 5_000
  @default_unmount_timeout 5_000

  @type state :: %{
          module: module(),
          component_state: term(),
          props: map(),
          lifecycle: :initialized | :mounted | :unmounted,
          id: term(),
          hooks: %{atom() => [function()]}
        }

  # Client API

  @doc """
  Starts a component server.

  ## Parameters

  - `module` - Component module
  - `props` - Initial properties
  - `opts` - Options (`:id`, `:timeout`)
  """
  @spec start_link(module(), map(), keyword()) :: GenServer.on_start()
  def start_link(module, props, opts \\ []) do
    id = Keyword.get(opts, :id, make_ref())
    name = Keyword.get(opts, :name)

    gen_opts = if name, do: [name: name], else: []

    GenServer.start_link(__MODULE__, {module, props, id, opts}, gen_opts)
  end

  @doc """
  Triggers the mount lifecycle stage.

  Called when the component is added to the active component tree.
  """
  @spec mount(pid()) :: :ok | {:error, term()}
  def mount(pid) do
    GenServer.call(pid, :mount)
  end

  @doc """
  Updates the component's props.

  Triggers the update callback if props have changed.
  """
  @spec update_props(pid(), map()) :: :ok | {:error, term()}
  def update_props(pid, new_props) do
    GenServer.call(pid, {:update_props, new_props})
  end

  @doc """
  Triggers the unmount lifecycle stage.

  Called when the component is removed from the tree.
  """
  @spec unmount(pid()) :: :ok
  def unmount(pid) do
    GenServer.call(pid, :unmount, @default_unmount_timeout)
  end

  @doc """
  Gets the current component state.
  """
  @spec get_state(pid()) :: term()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Gets the current props.
  """
  @spec get_props(pid()) :: map()
  def get_props(pid) do
    GenServer.call(pid, :get_props)
  end

  @doc """
  Gets the lifecycle state.
  """
  @spec get_lifecycle(pid()) :: :initialized | :mounted | :unmounted
  def get_lifecycle(pid) do
    GenServer.call(pid, :get_lifecycle)
  end

  @doc """
  Sends an event to the component.
  """
  @spec send_event(pid(), term()) :: :ok | {:error, term()}
  def send_event(pid, event) do
    GenServer.call(pid, {:event, event})
  end

  @doc """
  Registers a lifecycle hook.

  ## Hook Types

  - `:after_mount` - Called after successful mount
  - `:before_unmount` - Called before unmount cleanup
  - `:on_prop_change` - Called when props change
  """
  @spec register_hook(pid(), atom(), function()) :: :ok
  def register_hook(pid, hook_type, fun) when is_function(fun, 1) do
    GenServer.call(pid, {:register_hook, hook_type, fun})
  end

  # Server Callbacks

  @impl true
  def init({module, props, id, opts}) do
    timeout = Keyword.get(opts, :timeout, @default_init_timeout)

    # Validate that module implements required behaviour
    unless function_exported?(module, :init, 1) or function_exported?(module, :render, 2) do
      {:stop, {:error, :invalid_component_module}}
    else
      # Initialize component with timeout
      task =
        Task.async(fn ->
          try do
            if function_exported?(module, :init, 1) do
              module.init(props)
            else
              # Stateless component - no init needed
              {:ok, props}
            end
          rescue
            e -> {:error, {:init_error, e, __STACKTRACE__}}
          end
        end)

      case Task.yield(task, timeout) || Task.shutdown(task) do
        {:ok, {:ok, component_state}} ->
          state = %{
            module: module,
            component_state: component_state,
            props: props,
            lifecycle: :initialized,
            id: id,
            hooks: %{
              after_mount: [],
              before_unmount: [],
              on_prop_change: []
            }
          }

          {:ok, state}

        {:ok, {:ok, component_state, commands}} ->
          state = %{
            module: module,
            component_state: component_state,
            props: props,
            lifecycle: :initialized,
            id: id,
            hooks: %{
              after_mount: [],
              before_unmount: [],
              on_prop_change: []
            }
          }

          # Execute init commands
          execute_commands(commands, state)
          {:ok, state}

        {:ok, {:stop, reason}} ->
          {:stop, reason}

        {:ok, {:error, reason}} ->
          {:stop, reason}

        nil ->
          {:stop, {:init_timeout, timeout}}
      end
    end
  end

  @impl true
  def handle_call(:mount, _from, %{lifecycle: :initialized} = state) do
    module = state.module

    result =
      if function_exported?(module, :mount, 1) do
        try do
          module.mount(state.component_state)
        rescue
          e ->
            Logger.error("Mount error in #{inspect(module)}: #{inspect(e)}")
            {:error, {:mount_error, e}}
        end
      else
        {:ok, state.component_state}
      end

    case result do
      {:ok, new_component_state} ->
        new_state = %{state | component_state: new_component_state, lifecycle: :mounted}
        # Register in registry
        ComponentRegistry.register(state.id, self(), state.module)
        # Execute after_mount hooks
        execute_hooks(:after_mount, new_state)
        {:reply, :ok, new_state}

      {:ok, new_component_state, commands} ->
        new_state = %{state | component_state: new_component_state, lifecycle: :mounted}
        ComponentRegistry.register(state.id, self(), state.module)
        execute_commands(commands, new_state)
        execute_hooks(:after_mount, new_state)
        {:reply, :ok, new_state}

      {:stop, reason} ->
        {:stop, reason, {:error, reason}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:mount, _from, %{lifecycle: lifecycle} = state) do
    {:reply, {:error, {:invalid_lifecycle, lifecycle, :expected_initialized}}, state}
  end

  @impl true
  def handle_call({:update_props, new_props}, _from, %{lifecycle: :mounted} = state) do
    if props_changed?(state.props, new_props) do
      module = state.module

      result =
        if function_exported?(module, :update, 2) do
          try do
            module.update(new_props, state.component_state)
          rescue
            e ->
              Logger.error("Update error in #{inspect(module)}: #{inspect(e)}")
              {:error, {:update_error, e}}
          end
        else
          # Default: just update props, keep state
          {:ok, state.component_state}
        end

      case result do
        {:ok, new_component_state} ->
          new_state = %{state | component_state: new_component_state, props: new_props}
          execute_hooks(:on_prop_change, new_state)
          {:reply, :ok, new_state}

        {:ok, new_component_state, commands} ->
          new_state = %{state | component_state: new_component_state, props: new_props}
          execute_commands(commands, new_state)
          execute_hooks(:on_prop_change, new_state)
          {:reply, :ok, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      # Props unchanged, no update needed
      {:reply, :ok, state}
    end
  end

  def handle_call({:update_props, _new_props}, _from, %{lifecycle: lifecycle} = state) do
    {:reply, {:error, {:invalid_lifecycle, lifecycle, :expected_mounted}}, state}
  end

  @impl true
  def handle_call(:unmount, _from, %{lifecycle: :mounted} = state) do
    # Execute before_unmount hooks
    execute_hooks(:before_unmount, state)

    module = state.module

    if function_exported?(module, :unmount, 1) do
      try do
        module.unmount(state.component_state)
      rescue
        e ->
          Logger.error("Unmount error in #{inspect(module)}: #{inspect(e)}")
      end
    end

    # Unregister from registry
    ComponentRegistry.unregister(state.id)

    new_state = %{state | lifecycle: :unmounted}
    {:reply, :ok, new_state}
  end

  def handle_call(:unmount, _from, %{lifecycle: lifecycle} = state) do
    {:reply, {:error, {:invalid_lifecycle, lifecycle, :expected_mounted}}, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.component_state, state}
  end

  @impl true
  def handle_call(:get_props, _from, state) do
    {:reply, state.props, state}
  end

  @impl true
  def handle_call(:get_lifecycle, _from, state) do
    {:reply, state.lifecycle, state}
  end

  @impl true
  def handle_call({:event, event}, _from, %{lifecycle: :mounted} = state) do
    module = state.module

    if function_exported?(module, :handle_event, 2) do
      case module.handle_event(event, state.component_state) do
        {:ok, new_component_state} ->
          {:reply, :ok, %{state | component_state: new_component_state}}

        {:ok, new_component_state, commands} ->
          execute_commands(commands, state)
          {:reply, :ok, %{state | component_state: new_component_state}}

        {:stop, reason, new_component_state} ->
          {:stop, reason, :ok, %{state | component_state: new_component_state}}
      end
    else
      {:reply, {:error, :no_event_handler}, state}
    end
  end

  def handle_call({:event, _event}, _from, %{lifecycle: lifecycle} = state) do
    {:reply, {:error, {:invalid_lifecycle, lifecycle, :expected_mounted}}, state}
  end

  @impl true
  def handle_call({:register_hook, hook_type, fun}, _from, state) do
    hooks = Map.update!(state.hooks, hook_type, fn existing -> existing ++ [fun] end)
    {:reply, :ok, %{state | hooks: hooks}}
  end

  @impl true
  def terminate(reason, state) do
    # Ensure cleanup happens even on crash
    if state.lifecycle == :mounted do
      execute_hooks(:before_unmount, state)

      module = state.module

      if function_exported?(module, :unmount, 1) do
        try do
          module.unmount(state.component_state)
        rescue
          e ->
            Logger.error("Unmount error during terminate in #{inspect(module)}: #{inspect(e)}")
        end
      end

      ComponentRegistry.unregister(state.id)
    end

    Logger.debug("Component #{inspect(state.module)} terminating: #{inspect(reason)}")
    :ok
  end

  # Private Functions

  defp props_changed?(old_props, new_props) do
    old_props != new_props
  end

  defp execute_commands(commands, _state) when is_list(commands) do
    Enum.each(commands, fn
      {:send, pid, message} ->
        send(pid, message)

      {:timer, ms, message} ->
        Process.send_after(self(), message, ms)

      other ->
        Logger.warning("Unknown command: #{inspect(other)}")
    end)
  end

  defp execute_hooks(hook_type, state) do
    hooks = Map.get(state.hooks, hook_type, [])

    Enum.each(hooks, fn fun ->
      try do
        fun.(state.component_state)
      rescue
        e ->
          Logger.error("Hook error (#{hook_type}): #{inspect(e)}")
      end
    end)
  end
end
